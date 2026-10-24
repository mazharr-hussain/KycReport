--------------------------------------------------------------------------------
-- XXFND_FI_GEN_PKG (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The generators, run when an administrator activates an object or a drift is applied:
--   - the replica table XXFI_<code> (selected attributes, typed, primary key) and its staging table XXFI_<code>_STG
--     (every column as text, as files and JSON deliver it) - created when missing, then only missing columns added and
--     lengths widened (idempotent, through XXFND_DDL_PKG);
--   - the versioned business view XXFI_<code>_V<n> (selected attributes, business names as column comments) and the
--     stable business view XXFI_<code>_V the applications read, repointed to the applied version;
--   - the BICC datastore configuration (the selected columns, PUT /meta/datastores) and the BICC job of the object;
--   - the REST query of the object (fields, onlyData, paging).
--------------------------------------------------------------------------------
create or replace package xxfnd_fi_gen_pkg authid definer as
    -- The name of a generated object of the object (P_SUFFIX: null = replica table, _STG, _V, _V<n>).
    function object_name(p_object_id in number, p_suffix in varchar2 default null) return varchar2;
    -- The Oracle column type of an attribute (from the Fusion data type, length and scale).
    function sql_type(p_data_type in varchar2, p_length in number, p_scale in number) return varchar2;
    -- The selected attributes as JSON (the metadata of a version) and its SHA-256 hash.
    function metadata_json(p_object_id in number) return clob;
    function metadata_hash(p_object_id in number) return varchar2;
    -- Creates or completes the replica and staging tables of the object.
    procedure ensure_tables(p_object_id in number);
    -- A new version when the selected metadata changed: its view XXFI_<code>_V<n>, the stable view repointed to it.
    -- Returns the applied version number.
    function apply_version(p_object_id in number) return number;
    -- REST: the query string of a pull (selected fields, only data, paging; P_SINCE: changes after this date).
    function rest_query(p_object_id in number, p_offset in number, p_limit in number default 500,
                        p_since in timestamp default null) return varchar2;
    -- BICC: the datastore configured with the selected columns, and the object's BICC job (created when missing).
    procedure bicc_configure(p_object_id in number);
end xxfnd_fi_gen_pkg;
/

create or replace package body xxfnd_fi_gen_pkg as

    function obj(p_object_id in number) return xxfnd_fi_objects%rowtype is
        l_row xxfnd_fi_objects%rowtype;
    begin
        select * into l_row from xxfnd_fi_objects where object_id = p_object_id;
        return l_row;
    exception
        when no_data_found then
            xxfnd_error_pkg.raise_error('XXFND_FI_UNKNOWN', apex_t_varchar2(to_char(p_object_id)));
    end obj;

    function object_name(p_object_id in number, p_suffix in varchar2 default null) return varchar2 is
    begin
        return dbms_assert.simple_sql_name('XXFI_' || obj(p_object_id).object_code || p_suffix);
    end object_name;

    function sql_type(p_data_type in varchar2, p_length in number, p_scale in number) return varchar2 is
        l_type varchar2(60) := upper(p_data_type);
    begin
        if l_type like '%TIMESTAMP%' or l_type like '%DATETIME%' then
            return 'timestamp';
        elsif l_type = 'DATE' then
            return 'date';
        elsif l_type in ('NUMBER', 'NUMERIC', 'DECIMAL', 'BIGDECIMAL', 'INTEGER', 'INT', 'LONG', 'DOUBLE', 'FLOAT') then
            return 'number';
        elsif l_type in ('CLOB', 'BLOB', 'LONGVARCHAR') then
            return 'clob';
        elsif l_type = 'BOOLEAN' then
            return 'varchar2(5)';
        end if;
        return 'varchar2(' || least(greatest(nvl(p_length, 4000), 1), 4000) || ' char)';
    end sql_type;

    function metadata_json(p_object_id in number) return clob is
        l_json clob;
    begin
        select json_arrayagg(json_object('name' value attribute_name, 'column' value column_name,
                                         'type' value data_type, 'length' value data_length, 'scale' value data_scale,
                                         'pk' value pk_flag, 'business' value business_name)
                             order by display_sequence, attribute_name returning clob)
          into l_json
          from xxfnd_fi_attributes
         where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE';
        return nvl(l_json, to_clob('[]'));
    end metadata_json;

    function metadata_hash(p_object_id in number) return varchar2 is
    begin
        return rawtohex(dbms_crypto.hash(metadata_json(p_object_id), dbms_crypto.hash_sh256));
    end metadata_hash;

    procedure ensure_tables(p_object_id in number) is
        l_table varchar2(128) := object_name(p_object_id);
        l_stg   varchar2(128) := object_name(p_object_id, '_STG');
        l_cols  varchar2(32767);
        l_scols varchar2(32767);
        l_pk    varchar2(4000);
        l_n     pls_integer;
    begin
        for a in (select column_name, sql_type(data_type, data_length, data_scale) col_type, pk_flag
                    from xxfnd_fi_attributes
                   where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE'
                   order by display_sequence, attribute_name) loop
            l_cols  := l_cols || ', ' || a.column_name || ' ' || a.col_type;
            l_scols := l_scols || ', ' || a.column_name || ' varchar2(4000 char)';
            if a.pk_flag = 'Y' then
                l_pk := l_pk || ', ' || a.column_name;
            end if;
        end loop;
        if l_cols is null then
            xxfnd_error_pkg.raise_error('XXFND_FI_NO_ATTRIBUTES', apex_t_varchar2(l_table));
        end if;
        -- the tables, when missing
        if xxfnd_ddl_pkg.create_table(l_table, 'create table ' || l_table || ' (' || ltrim(l_cols, ', ')
               || ', xxfi_sync_date timestamp default systimestamp not null)') then
            execute immediate 'comment on table ' || l_table || ' is ''Release 107: Fusion object replica (generated by '
                || 'XXFND_FI_GEN_PKG; read through the business view ' || l_table || '_V).''';
        end if;
        xxfnd_ddl_pkg.ensure_table(l_stg, 'create table ' || l_stg || ' (' || ltrim(l_scols, ', ') || ')');
        -- what is missing, and longer text columns (non-breaking drift)
        for a in (select column_name, sql_type(data_type, data_length, data_scale) col_type, data_length
                    from xxfnd_fi_attributes
                   where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE') loop
            xxfnd_ddl_pkg.add_column(l_table, a.column_name, a.col_type);
            xxfnd_ddl_pkg.add_column(l_stg, a.column_name, 'varchar2(4000 char)');
            select count(*) into l_n from user_tab_columns
             where table_name = l_table and column_name = a.column_name and data_type = 'VARCHAR2'
               and char_length < least(nvl(a.data_length, 4000), 4000);
            if l_n > 0 then
                execute immediate 'alter table ' || l_table || ' modify (' || a.column_name || ' ' || a.col_type || ')';
            end if;
        end loop;
        if l_pk is not null then
            xxfnd_ddl_pkg.add_constraint(l_table, substr(l_table, 1, 125) || '_PK', 'primary key (' || ltrim(l_pk, ', ') || ')');
        end if;
    end ensure_tables;

    function apply_version(p_object_id in number) return number is
        l_o     xxfnd_fi_objects%rowtype := obj(p_object_id);
        l_hash  varchar2(64) := metadata_hash(p_object_id);
        l_last  varchar2(64);
        l_ver   number;
        l_view  varchar2(128);
        l_cols  varchar2(32767);
    begin
        select max(metadata_hash) keep (dense_rank last order by version_no) into l_last
          from xxfnd_fi_versions where object_id = p_object_id;
        if l_last = l_hash then
            return l_o.current_version;
        end if;
        ensure_tables(p_object_id);
        l_ver  := l_o.current_version + 1;
        l_view := object_name(p_object_id, '_V' || l_ver);
        select listagg(column_name, ', ') within group (order by display_sequence, attribute_name) into l_cols
          from xxfnd_fi_attributes
         where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE';
        execute immediate 'create or replace view ' || l_view || ' as select ' || l_cols || ', xxfi_sync_date from '
            || object_name(p_object_id);
        for a in (select column_name, nvl(business_name, attribute_name) label from xxfnd_fi_attributes
                   where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE') loop
            execute immediate 'comment on column ' || l_view || '.' || a.column_name || ' is '
                || dbms_assert.enquote_literal(replace(substr(a.label, 1, 3900), '''', ''''''));
        end loop;
        -- the stable business view the applications read
        execute immediate 'create or replace view ' || object_name(p_object_id, '_V') || ' as select * from ' || l_view;
        execute immediate 'comment on table ' || object_name(p_object_id, '_V') || ' is '
            || dbms_assert.enquote_literal('Release 107: business view of the Fusion object ' || replace(l_o.business_name, '''', '''''')
                                           || ' (version ' || l_ver || '; XXFND_FI_GEN_PKG)');
        insert into xxfnd_fi_versions (object_id, version_no, metadata_hash, metadata_json, view_name, applied_date)
        values (p_object_id, l_ver, l_hash, metadata_json(p_object_id), l_view, systimestamp);
        update xxfnd_fi_objects
           set current_version = l_ver, replica_table = object_name(p_object_id),
               business_view = object_name(p_object_id, '_V')
         where object_id = p_object_id;
        return l_ver;
    end apply_version;

    function rest_query(p_object_id in number, p_offset in number, p_limit in number default 500,
                        p_since in timestamp default null) return varchar2 is
        l_fields varchar2(32767);
        l_lud    varchar2(400);
    begin
        select listagg(attribute_name, ',') within group (order by display_sequence),
               max(case when last_update_flag = 'Y' then attribute_name end)
          into l_fields, l_lud
          from xxfnd_fi_attributes
         where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE';
        return 'onlyData=true&limit=' || p_limit || '&offset=' || nvl(p_offset, 0)
            || '&fields=' || utl_url.escape(l_fields, true)
            || case when p_since is not null and l_lud is not null
                    then '&q=' || utl_url.escape(l_lud || '>''' || to_char(p_since, 'YYYY-MM-DD"T"HH24:MI:SS') || '''', true) end;
    end rest_query;

    procedure bicc_configure(p_object_id in number) is
        l_o     xxfnd_fi_objects%rowtype := obj(p_object_id);
        l_path  varchar2(1000) := xxfnd_fi_meta_pkg.c_bicc_root || '/datastores/' || utl_url.escape(l_o.source_name, true);
        l_ds    json_object_t;
        l_cols  json_array_t;
        l_col   json_object_t;
        l_name  varchar2(400);
        l_n     pls_integer;
        l_job   json_object_t;
        l_resp  json_object_t;
        l_store json_array_t := json_array_t();
        l_one   json_object_t := json_object_t();
        l_body  clob;
        l_jobid varchar2(100);
    begin
        -- the datastore with its columns; each column populated when it is selected (primary keys always)
        l_ds := json_object_t.parse(xxfnd_fi_meta_pkg.fusion_get(l_path, 'includeCustomization=true'));
        l_cols := case when l_ds.has('columns') then l_ds.get_array('columns')
                       when l_ds.has('datastoreColumns') then l_ds.get_array('datastoreColumns')
                       else json_array_t() end;
        for i in 0 .. l_cols.get_size - 1 loop
            l_col  := treat(l_cols.get(i) as json_object_t);
            l_name := case when l_col.has('name') then l_col.get_string('name') else l_col.get_string('columnName') end;
            select count(*) into l_n from xxfnd_fi_attributes
             where object_id = p_object_id and attribute_name = l_name and status_code = 'ACTIVE'
               and (selected_flag = 'Y' or pk_flag = 'Y');
            l_col.put('isPopulate', l_n > 0);
        end loop;
        l_body := xxfnd_fi_meta_pkg.fusion_send('PUT', l_path, l_ds.to_clob);
        -- the job of the object (one datastore), when it has none
        if l_o.bicc_job_id is null then
            l_one.put('dataStoreId', l_o.source_name);
            l_one.put('offeringId', l_o.offering_code);
            l_store.append(l_one);
            l_job := json_object_t();
            l_job.put('name', object_name(p_object_id));
            l_job.put('description', 'Fusion Objects (COMMON): ' || l_o.business_name);
            l_job.put('dataStores', l_store);
            l_resp := json_object_t.parse(xxfnd_fi_meta_pkg.fusion_send('POST', xxfnd_fi_meta_pkg.c_bicc_root || '/jobs',
                                                                        l_job.to_clob));
            for k in (select column_value key from table(apex_t_varchar2('id', 'jobId'))) loop
                if l_jobid is null and l_resp.has(k.key) and not l_resp.get(k.key).is_null then
                    l_jobid := case when l_resp.get(k.key).is_string then l_resp.get_string(k.key)
                                    else l_resp.get(k.key).to_string end;
                end if;
            end loop;
            update xxfnd_fi_objects
               set bicc_job_id = l_jobid
             where object_id = p_object_id;
        end if;
    end bicc_configure;

end xxfnd_fi_gen_pkg;
/
