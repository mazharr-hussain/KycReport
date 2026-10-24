--------------------------------------------------------------------------------
-- XXFND_FI_RUN_PKG (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The runtime of the onboarded objects (automation "Fusion Objects run" calls RUN_DUE):
--   - BICC replica: the object's BICC job is started from APEX (BICC REST, through the Fusion server and credential),
--     its status polled; when done, the extract files written to Object Storage (the object's OBJECT_STORAGE server,
--     bucket and prefix) are read with DBMS_CLOUD, unzipped (APEX_ZIP), parsed (APEX_DATA_PARSER) into the staging
--     table and merged into the replica; the primary-key extract (files with "pecsv") removes deleted rows.
--     DBMS_CLOUD is called through dynamic SQL: the package compiles without it and a run says what is missing.
--   - REST replica: paged pulls of the selected fields (incremental by the last-update attribute when there is one)
--     into staging, then merged; a full pull removes the rows Fusion no longer returns.
--   - Real-time and push: FETCH and PUSH, the shared REST calls the applications use.
--   Every run is logged (XXFND_FI_RUNS) and the object's last sync updated; failures alert the administrators.
--------------------------------------------------------------------------------
create or replace package xxfnd_fi_run_pkg authid definer as
    -- BICC job paths (relative to XXFND_FI_META_PKG.C_BICC_ROOT); {job} / {request} are replaced.
    c_bicc_run    constant varchar2(200) := '/jobs/{job}/schedules';
    c_bicc_status constant varchar2(200) := '/jobs/{job}/schedules/{request}';
    c_page_size   constant pls_integer   := 500;

    -- The automation's entry: every due ACTIVE replica object, then the daily metadata check.
    procedure run_due;
    -- One object now (Run now on the Object Detail screen); FUSION_OBJECTS - Manage in an APEX session.
    procedure run_object(p_object_id in number);
    -- Text from a file or JSON to a timestamp (the formats BICC and Fusion REST use); null when not a date.
    function to_ts(p_text in varchar2) return timestamp;
    -- Real-time (FETCH_ROWS): a GET on the object's REST resource (P_QUERY: q=..., fields=..., limit=...).
    function fetch_rows(p_object_id in number, p_query in varchar2 default null) return clob;
    -- Push: POST (create) or PATCH / DELETE of one row (P_KEY) of the object's REST resource.
    function push(p_object_id in number, p_payload in clob, p_method in varchar2 default 'POST',
                  p_key in varchar2 default null) return clob;
end xxfnd_fi_run_pkg;
/

create or replace package body xxfnd_fi_run_pkg as

    function to_ts(p_text in varchar2) return timestamp is
        l_t varchar2(100) := trim(p_text);
    begin
        if l_t is null then
            return null;
        end if;
        l_t := replace(regexp_replace(l_t, '(Z|[+-][0-9]{2}:?[0-9]{2})$', ''), 'T', ' ');
        return coalesce(to_timestamp(l_t default null on conversion error, 'YYYY-MM-DD HH24:MI:SS.FF'),
                        to_timestamp(l_t default null on conversion error, 'YYYY-MM-DD HH24:MI:SS'),
                        to_timestamp(l_t default null on conversion error, 'YYYY-MM-DD'),
                        to_timestamp(l_t default null on conversion error, 'MM/DD/YYYY HH24:MI:SS'));
    end to_ts;

    function obj(p_object_id in number) return xxfnd_fi_objects%rowtype is
        l_row xxfnd_fi_objects%rowtype;
    begin
        select * into l_row from xxfnd_fi_objects where object_id = p_object_id;
        return l_row;
    exception
        when no_data_found then
            xxfnd_error_pkg.raise_error('XXFND_FI_UNKNOWN', apex_t_varchar2(to_char(p_object_id)));
    end obj;

    function start_run(p_object_id in number, p_type in varchar2) return number is
        l_id number;
    begin
        insert into xxfnd_fi_runs (object_id, run_type) values (p_object_id, p_type) returning run_id into l_id;
        update xxfnd_fi_objects set last_status = 'RUNNING' where object_id = p_object_id;
        commit;
        return l_id;
    end start_run;

    procedure end_run(p_run_id in number, p_status in varchar2, p_message in varchar2 default null,
                      p_loaded in number default null, p_merged in number default null, p_deleted in number default null) is
        l_object number;
        l_o      xxfnd_fi_objects%rowtype;
    begin
        update xxfnd_fi_runs
           set status_code = p_status, ended_date = case when p_status <> 'WAITING' then systimestamp end,
               message = substr(p_message, 1, 4000), rows_loaded = p_loaded, rows_merged = p_merged, rows_deleted = p_deleted
         where run_id = p_run_id
        returning object_id into l_object;
        l_o := obj(l_object);
        update xxfnd_fi_objects
           set last_status   = p_status,
               last_message  = substr(p_message, 1, 4000),
               last_sync_date = case when p_status = 'SUCCESS' then systimestamp else last_sync_date end,
               -- waiting for BICC: polled again soon; otherwise the next scheduled run
               next_run_date = case when p_status = 'WAITING' then systimestamp + numtodsinterval(5, 'MINUTE')
                                    when mode_code = 'REPLICA' and status_code = 'ACTIVE'
                                    then systimestamp + numtodsinterval(nvl(schedule_minutes, 1440), 'MINUTE') end
         where object_id = l_object;
        commit;
        if p_status = 'FAILED' then
            xxfnd_fi_drift_pkg.alert(l_object, 'Run failed: ' || p_message);
        end if;
    end end_run;

    function pk_list(p_object_id in number, p_prefix in varchar2 default null) return varchar2 is
        l_list varchar2(4000);
    begin
        select listagg(case when p_prefix is not null then 't.' || column_name || ' = ' || p_prefix || '.' || column_name
                            else column_name end,
                       case when p_prefix is not null then ' and ' else ', ' end)
                 within group (order by display_sequence)
          into l_list
          from xxfnd_fi_attributes
         where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE' and pk_flag = 'Y';
        return l_list;
    end pk_list;

    -- the staging text of a column converted to the replica's type
    function conv(p_column in varchar2, p_type in varchar2) return varchar2 is
    begin
        return case when p_type = 'number' then 'to_number(s.' || p_column || ' default null on conversion error)'
                    when p_type = 'timestamp' then 'xxfnd_fi_run_pkg.to_ts(s.' || p_column || ')'
                    when p_type = 'date' then 'cast(xxfnd_fi_run_pkg.to_ts(s.' || p_column || ') as date)'
                    when p_type = 'clob' then 'to_clob(s.' || p_column || ')'
                    else 's.' || p_column end;
    end conv;

    -- the staging rows merged into the replica (one row per key: the last staged); returns the rows merged
    function merge_staging(p_object_id in number) return number is
        l_table varchar2(128) := xxfnd_fi_gen_pkg.object_name(p_object_id);
        l_stg   varchar2(128) := xxfnd_fi_gen_pkg.object_name(p_object_id, '_STG');
        l_sel   varchar2(32767);
        l_set   varchar2(32767);
        l_ins   varchar2(32767);
        l_val   varchar2(32767);
        l_pk    varchar2(4000) := pk_list(p_object_id);
    begin
        for a in (select column_name, pk_flag,
                         xxfnd_fi_gen_pkg.sql_type(data_type, data_length, data_scale) col_type
                    from xxfnd_fi_attributes
                   where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE'
                   order by display_sequence) loop
            l_sel := l_sel || ', ' || conv(a.column_name, regexp_substr(a.col_type, '^[a-z0-9]+')) || ' ' || a.column_name;
            l_ins := l_ins || ', ' || a.column_name;
            l_val := l_val || ', x.' || a.column_name;
            if a.pk_flag = 'N' then
                l_set := l_set || ', t.' || a.column_name || ' = x.' || a.column_name;
            end if;
        end loop;
        execute immediate
            'merge into ' || l_table || ' t using ('
            || 'select * from (select ' || ltrim(l_sel, ', ') || ', row_number() over (partition by '
            || 's.' || replace(l_pk, ', ', ', s.') || ' order by null) xxfi_rn from ' || l_stg || ' s) where xxfi_rn = 1) x'
            || ' on (' || pk_list(p_object_id, 'x') || ')'
            || case when l_set is not null
                    then ' when matched then update set ' || ltrim(l_set, ', ') || ', t.xxfi_sync_date = systimestamp' end
            || ' when not matched then insert (' || ltrim(l_ins, ', ') || ', xxfi_sync_date) values ('
            || ltrim(l_val, ', ') || ', systimestamp)';
        return sql%rowcount;
    end merge_staging;

    ---------------------------------------------------------------- BICC
    function storage_uri(p_o in xxfnd_fi_objects%rowtype, p_cred out varchar2) return varchar2 is
        l_s xxfnd_integration_pkg.t_server;
    begin
        if p_o.storage_server_code is null or p_o.storage_bucket is null then
            xxfnd_error_pkg.raise_error('XXFND_FI_NO_STORAGE', apex_t_varchar2(p_o.object_code));
        end if;
        l_s := xxfnd_integration_pkg.server(p_o.storage_server_code);
        p_cred := l_s.credential_static_id;
        return 'https://objectstorage.' || l_s.oci_region || '.oraclecloud.com/n/' || l_s.oci_namespace
            || '/b/' || p_o.storage_bucket || '/o/' || case when p_o.storage_prefix is not null
                                                              then rtrim(p_o.storage_prefix, '/') || '/' end;
    end storage_uri;

    function cloud_get(p_cred in varchar2, p_uri in varchar2) return blob is
        l_blob blob;
    begin
        execute immediate 'begin :b := dbms_cloud.get_object(credential_name => :c, object_uri => :u); end;'
            using out l_blob, in p_cred, in p_uri;
        return l_blob;
    end cloud_get;

    -- loads one CSV into the staging table, columns matched by header to the attributes; returns the rows loaded
    function load_csv(p_object_id in number, p_content in blob, p_table in varchar2, p_pk_only in boolean) return number is
        l_cols   varchar2(32767);
        l_vals   varchar2(32767);
        l_header apex_t_varchar2 := apex_t_varchar2();
        l_pos    pls_integer;
        l_pkonly varchar2(1) := case when p_pk_only then 'Y' else 'N' end;
    begin
        -- the header row (APEX_DATA_PARSER profile of the file)
        for h in (select column_position, column_name from table(apex_data_parser.get_columns(
                      apex_data_parser.discover(p_content => p_content, p_file_name => 'extract.csv')))) loop
            l_header.extend;
            l_header(l_header.count) := upper(regexp_replace(h.column_name, '[^A-Za-z0-9]', ''));
        end loop;
        for a in (select column_name, upper(regexp_replace(attribute_name, '[^A-Za-z0-9]', '')) key_name,
                         upper(regexp_replace(regexp_substr(attribute_name, '[^.]+$'), '[^A-Za-z0-9]', '')) short_name
                    from xxfnd_fi_attributes
                   where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE'
                     and (pk_flag = 'Y' or l_pkonly = 'N')) loop
            l_pos := null;
            for i in 1 .. l_header.count loop
                if l_header(i) in (a.key_name, a.short_name, upper(a.column_name)) then
                    l_pos := i;
                    exit;
                end if;
            end loop;
            if l_pos is not null and l_pos <= 300 then
                l_cols := l_cols || ', ' || a.column_name;
                l_vals := l_vals || ', col' || lpad(l_pos, 3, '0');
            end if;
        end loop;
        if l_cols is null then
            return 0;
        end if;
        execute immediate 'insert into ' || p_table || ' (' || ltrim(l_cols, ', ') || ') select ' || ltrim(l_vals, ', ')
            || q'~ from table(apex_data_parser.parse(p_content => :c, p_file_name => 'extract.csv', p_skip_rows => 1))~'
            using p_content;
        return sql%rowcount;
    end load_csv;

    procedure bicc_load(p_object_id in number, p_run_id in number) is
        type t_names is table of varchar2(1024);
        type t_dates is table of timestamp with time zone;
        l_o       xxfnd_fi_objects%rowtype := obj(p_object_id);
        l_cred    varchar2(255);
        l_uri     varchar2(2000) := storage_uri(l_o, l_cred);
        l_key     varchar2(400) := lower(replace(l_o.source_name, '.', '_'));
        l_names   t_names;
        l_dates   t_dates;
        l_blob    blob;
        l_files   apex_zip.t_files;
        l_pk_tab  varchar2(128) := xxfnd_fi_gen_pkg.object_name(p_object_id, '_PK');
        l_stg     varchar2(128) := xxfnd_fi_gen_pkg.object_name(p_object_id, '_STG');
        l_pk      boolean;
        l_any_pk  boolean := false;
        l_loaded  number := 0;
        l_merged  number := 0;
        l_deleted number := 0;
        l_newest  timestamp;

        procedure one(p_content in blob) is
        begin
            l_loaded := l_loaded + load_csv(p_object_id, p_content, case when l_pk then l_pk_tab else l_stg end, l_pk);
        end one;
    begin
        xxfnd_fi_gen_pkg.ensure_tables(p_object_id);
        xxfnd_ddl_pkg.ensure_table(l_pk_tab, 'create table ' || l_pk_tab || ' as select '
            || pk_list(p_object_id) || ' from ' || l_stg || ' where 1 = 0');
        execute immediate 'truncate table ' || l_stg;
        execute immediate 'truncate table ' || l_pk_tab;
        -- the extract files of the datastore written since the last load
        execute immediate 'select object_name, last_modified from dbms_cloud.list_objects(:c, :u)'
                       || ' where lower(object_name) like :k and last_modified > :d order by last_modified'
            bulk collect into l_names, l_dates
            using l_cred, l_uri, '%' || l_key || '%', nvl(l_o.last_extract_date, timestamp '1900-01-01 00:00:00');
        for i in 1 .. l_names.count loop
            l_pk := instr(lower(l_names(i)), 'pecsv') > 0;
            l_any_pk := l_any_pk or l_pk;
            l_blob := cloud_get(l_cred, l_uri || l_names(i));
            if lower(l_names(i)) like '%.zip' then
                l_files := apex_zip.get_files(l_blob);
                for f in 1 .. l_files.count loop
                    if lower(l_files(f)) like '%.csv' then
                        one(apex_zip.get_file_content(l_blob, l_files(f)));
                    end if;
                end loop;
            elsif lower(l_names(i)) like '%.gz' then
                one(utl_compress.lz_uncompress(l_blob));
            else
                one(l_blob);
            end if;
            l_newest := greatest(nvl(l_newest, cast(l_dates(i) as timestamp)), cast(l_dates(i) as timestamp));
        end loop;
        l_merged := merge_staging(p_object_id);
        if l_any_pk then
            execute immediate 'delete from ' || xxfnd_fi_gen_pkg.object_name(p_object_id) || ' t where not exists '
                || '(select 1 from ' || l_pk_tab || ' p where ' || pk_list(p_object_id, 'p') || ')';
            l_deleted := sql%rowcount;
        end if;
        update xxfnd_fi_objects set last_extract_date = nvl(l_newest, last_extract_date) where object_id = p_object_id;
        end_run(p_run_id, 'SUCCESS', l_names.count || ' file(s) loaded', l_loaded, l_merged, l_deleted);
    end bicc_load;

    function bicc_path(p_template in varchar2, p_job in varchar2, p_request in varchar2 default null) return varchar2 is
    begin
        return xxfnd_fi_meta_pkg.c_bicc_root || replace(replace(p_template, '{job}', utl_url.escape(p_job, true)),
                                                       '{request}', utl_url.escape(p_request, true));
    end bicc_path;

    function json_text(p_obj in json_object_t, p_keys in varchar2) return varchar2 is
    begin
        for k in (select column_value key from table(apex_string.split(p_keys, ','))) loop
            if p_obj.has(k.key) and not p_obj.get(k.key).is_null then
                return case when p_obj.get(k.key).is_string then p_obj.get_string(k.key) else p_obj.get(k.key).to_string end;
            end if;
        end loop;
        return null;
    end json_text;

    procedure run_bicc(p_object_id in number) is
        l_o      xxfnd_fi_objects%rowtype := obj(p_object_id);
        l_wait   xxfnd_fi_runs%rowtype;
        l_run    number;
        l_body   json_object_t := json_object_t();
        l_resp   json_object_t;
        l_status varchar2(100);
    begin
        if l_o.bicc_job_id is null then
            xxfnd_fi_gen_pkg.bicc_configure(p_object_id);
            l_o := obj(p_object_id);
        end if;
        select max(run_id) into l_wait.run_id from xxfnd_fi_runs
         where object_id = p_object_id and run_type = 'EXTRACT' and status_code = 'WAITING';
        if l_wait.run_id is null then
            -- start the extract now
            l_run := start_run(p_object_id, 'EXTRACT');
            l_body.put('name', 'XXFI ' || l_o.object_code || ' ' || to_char(systimestamp, 'YYYYMMDDHH24MISS'));
            l_body.put('type', 'SIMPLE');
            l_body.put('frequencyType', 'IMMEDIATE');
            l_resp := json_object_t.parse(xxfnd_fi_meta_pkg.fusion_send('POST', bicc_path(c_bicc_run, l_o.bicc_job_id),
                                                                        l_body.to_clob));
            update xxfnd_fi_runs set bicc_request_id = json_text(l_resp, 'id,scheduleId,requestId,jobRequestId')
             where run_id = l_run;
            end_run(l_run, 'WAITING', 'BICC extract started');
            return;
        end if;
        select * into l_wait from xxfnd_fi_runs where run_id = l_wait.run_id;
        l_resp := json_object_t.parse(xxfnd_fi_meta_pkg.fusion_get(bicc_path(c_bicc_status, l_o.bicc_job_id,
                                                                             l_wait.bicc_request_id)));
        l_status := upper(json_text(l_resp, 'status,jobStatus,state'));
        if l_status in ('SUCCEEDED', 'SUCCESS', 'COMPLETED', 'FINISHED') then
            end_run(l_wait.run_id, 'SUCCESS', 'BICC extract ' || l_status);
            l_run := start_run(p_object_id, 'LOAD');
            begin
                bicc_load(p_object_id, l_run);
            exception
                when others then
                    rollback;
                    end_run(l_run, 'FAILED', sqlerrm);
            end;
        elsif l_status in ('FAILED', 'ERROR', 'CANCELLED', 'CANCELED', 'WARNING') then
            end_run(l_wait.run_id, 'FAILED', 'BICC extract ' || l_status);
        else
            end_run(l_wait.run_id, 'WAITING', 'BICC extract ' || nvl(l_status, 'running'));
        end if;
    end run_bicc;

    ---------------------------------------------------------------- REST
    procedure run_rest(p_object_id in number) is
        l_o       xxfnd_fi_objects%rowtype := obj(p_object_id);
        l_run     number;
        l_stg     varchar2(128) := xxfnd_fi_gen_pkg.object_name(p_object_id, '_STG');
        l_cols    varchar2(32767);
        l_paths   varchar2(32767);
        l_resp    clob;
        l_offset  number := 0;
        l_since   timestamp;
        l_lud     pls_integer;
        l_more    varchar2(10);
        l_loaded  number := 0;
        l_merged  number;
        l_deleted number := 0;
        l_start   timestamp := systimestamp;
    begin
        if instr(l_o.source_name, '{id}') > 0 then
            xxfnd_error_pkg.raise_error('XXFND_FI_CHILD_REPLICA', apex_t_varchar2(l_o.object_code));
        end if;
        l_run := start_run(p_object_id, 'REST');
        xxfnd_fi_gen_pkg.ensure_tables(p_object_id);
        execute immediate 'truncate table ' || l_stg;
        select listagg(column_name, ', ') within group (order by display_sequence),
               listagg(column_name || ' varchar2(4000) path ''$."' || replace(attribute_name, '"', '') || '"''', ', ')
                 within group (order by display_sequence),
               count(case when last_update_flag = 'Y' then 1 end)
          into l_cols, l_paths, l_lud
          from xxfnd_fi_attributes
         where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE';
        l_since := case when l_lud > 0 then cast(l_o.last_sync_date as timestamp) end;
        loop
            l_resp := xxfnd_fi_meta_pkg.fusion_get(l_o.source_name,
                                                   xxfnd_fi_gen_pkg.rest_query(p_object_id, l_offset, c_page_size, l_since));
            execute immediate 'insert into ' || l_stg || ' (' || l_cols || ') select ' || l_cols
                || ' from json_table(:r, ''$.items[*]'' columns (' || l_paths || '))' using l_resp;
            l_loaded := l_loaded + sql%rowcount;
            select lower(json_value(l_resp, '$.hasMore')) into l_more from dual;
            exit when nvl(l_more, 'false') <> 'true';
            l_offset := l_offset + c_page_size;
        end loop;
        l_merged := merge_staging(p_object_id);
        if l_since is null then
            -- a full pull: what Fusion no longer returns is removed
            execute immediate 'delete from ' || xxfnd_fi_gen_pkg.object_name(p_object_id) || ' where xxfi_sync_date < :s'
                using l_start;
            l_deleted := sql%rowcount;
        end if;
        end_run(l_run, 'SUCCESS', case when l_since is null then 'Full pull' else 'Changes since ' || to_char(l_since) end,
                l_loaded, l_merged, l_deleted);
    exception
        when others then
            rollback;
            if l_run is not null then
                end_run(l_run, 'FAILED', sqlerrm);
            else
                raise;
            end if;
    end run_rest;

    ---------------------------------------------------------------- entry points
    procedure run_object(p_object_id in number) is
        l_o xxfnd_fi_objects%rowtype := obj(p_object_id);
    begin
        xxfnd_fi_registry_pkg.check_manage;
        if l_o.status_code <> 'ACTIVE' or l_o.mode_code <> 'REPLICA' then
            xxfnd_error_pkg.raise_error('XXFND_FI_NOT_RUNNABLE', apex_t_varchar2(l_o.object_code));
        end if;
        if l_o.source_type = 'BICC' then
            run_bicc(p_object_id);
        else
            run_rest(p_object_id);
        end if;
    end run_object;

    procedure run_due is
    begin
        for o in (select object_id from xxfnd_fi_objects
                   where status_code = 'ACTIVE' and mode_code = 'REPLICA'
                     and nvl(next_run_date, systimestamp) <= systimestamp
                   order by next_run_date nulls first) loop
            begin
                run_object(o.object_id);
            exception
                when others then
                    rollback;
                    update xxfnd_fi_objects
                       set last_status = 'FAILED', last_message = substr(sqlerrm, 1, 4000),
                           next_run_date = systimestamp + numtodsinterval(nvl(schedule_minutes, 1440), 'MINUTE')
                     where object_id = o.object_id;
                    commit;
                    xxfnd_fi_drift_pkg.alert(o.object_id, 'Run failed: ' || sqlerrm);
            end;
        end loop;
        xxfnd_fi_drift_pkg.check_all(24);
    end run_due;

    function fetch_rows(p_object_id in number, p_query in varchar2 default null) return clob is
        l_o xxfnd_fi_objects%rowtype := obj(p_object_id);
    begin
        if l_o.source_type <> 'REST' or l_o.status_code <> 'ACTIVE' then
            xxfnd_error_pkg.raise_error('XXFND_FI_NOT_RUNNABLE', apex_t_varchar2(l_o.object_code));
        end if;
        return xxfnd_fi_meta_pkg.fusion_get(l_o.source_name, p_query);
    end fetch_rows;

    function push(p_object_id in number, p_payload in clob, p_method in varchar2 default 'POST',
                  p_key in varchar2 default null) return clob is
        l_o xxfnd_fi_objects%rowtype := obj(p_object_id);
    begin
        if l_o.source_type <> 'REST' or l_o.status_code <> 'ACTIVE' or l_o.mode_code <> 'PUSH' then
            xxfnd_error_pkg.raise_error('XXFND_FI_NOT_RUNNABLE', apex_t_varchar2(l_o.object_code));
        end if;
        return xxfnd_fi_meta_pkg.fusion_send(p_method,
                                             l_o.source_name || case when p_key is not null then '/' || utl_url.escape(p_key, true) end,
                                             p_payload);
    end push;

end xxfnd_fi_run_pkg;
/
