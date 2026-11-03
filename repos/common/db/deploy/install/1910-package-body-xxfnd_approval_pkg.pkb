
create or replace package body xxfnd_approval_pkg as

    function pk_column(p_table_name in varchar2) return varchar2 is
        l_column xxfnd_config_tables.pk_column%type;
    begin
        -- release 48: the maker-checker tables each application registered (XXFND_CONFIG_TABLES)
        select max(pk_column) into l_column
          from xxfnd_config_tables
         where table_name = upper(p_table_name) and approval_flag = 'Y';
        return l_column;
    end pk_column;

    function is_controlled(p_table_name in varchar2) return boolean is
    begin
        return pk_column(p_table_name) is not null;
    end is_controlled;

    procedure set_status(p_table_name in varchar2, p_pk_value in varchar2, p_status in varchar2) is
        l_rows pls_integer;
    begin
        if not is_controlled(p_table_name) then
            raise_application_error(-20120, p_table_name || ' is not under maker-checker control.');
        end if;
        -- Table and column names come from the registry (XXFND_CONFIG_TABLES) only.
        -- release 54: owner-qualified - KYC tables are in the KYC schema
        execute immediate 'update ' || xxfnd_util_pkg.qualified(p_table_name)
                       || ' set approval_status = :s where ' || dbms_assert.simple_sql_name(pk_column(p_table_name)) || ' = :k'
            using p_status, p_pk_value;
        l_rows := sql%rowcount;
        if l_rows = 0 then
            raise_application_error(-20121, 'No ' || p_table_name || ' row with key ' || p_pk_value || '.');
        end if;
    end set_status;

    procedure submit(p_table_name in varchar2, p_pk_value in varchar2) is
    begin
        set_status(p_table_name, p_pk_value, 'PENDING_APPROVAL');
    end submit;

    procedure approve(p_table_name in varchar2, p_pk_value in varchar2) is
    begin
        set_status(p_table_name, p_pk_value, 'APPROVED');
    end approve;

    procedure reject(p_table_name in varchar2, p_pk_value in varchar2, p_reason in varchar2) is
    begin
        if p_reason is null then
            raise_application_error(-20122, 'Enter a reason for rejecting this change.');
        end if;
        xxfnd_audit_pkg.set_change_reason('Rejected: ' || p_reason);
        set_status(p_table_name, p_pk_value, 'REJECTED');
        xxfnd_audit_pkg.clear_change_reason;
    end reject;

    procedure apply_rules(p_inserting        in boolean,
                          p_old_status       in varchar2,
                          p_new_status       in out varchar2,
                          p_old_last_updated in varchar2,
                          p_approved_by      in out varchar2,
                          p_approved_date    in out timestamp) is
        l_user varchar2(255) := xxfnd_util_pkg.current_user;
    begin
        if p_inserting then
            -- Install scripts (no APEX session) may seed rows as APPROVED.
            if p_new_status = 'APPROVED' and xxfnd_util_pkg.in_apex_session then
                p_new_status := 'PENDING_APPROVAL';
            end if;
            if p_new_status = 'APPROVED' then
                p_approved_by   := l_user;
                p_approved_date := systimestamp;
            else
                p_approved_by   := null;
                p_approved_date := null;
            end if;
            return;
        end if;

        -- release 74: install and upgrade scripts (no APEX session) may also set a row back to approved (a seed fix)
        if p_new_status = 'APPROVED' and not xxfnd_util_pkg.in_apex_session then
            p_approved_by   := nvl(p_approved_by, l_user);
            p_approved_date := nvl(p_approved_date, systimestamp);
            return;
        end if;
        if p_new_status = 'APPROVED' and nvl(p_old_status, '#') <> 'APPROVED' then
            if p_old_status <> 'PENDING_APPROVAL' then
                raise_application_error(-20123, 'Only a change that is pending approval can be approved.');
            end if;
            if upper(l_user) = upper(p_old_last_updated) then
                raise_application_error(-20124, 'You made this change, so someone else must approve it.');
            end if;
            p_approved_by   := l_user;
            p_approved_date := systimestamp;
        elsif p_new_status = nvl(p_old_status, '#') then
            -- A content edit (status untouched): approved rows go back for approval.
            if p_old_status in ('APPROVED','REJECTED') then
                p_new_status := 'PENDING_APPROVAL';
            end if;
            p_approved_by   := null;
            p_approved_date := null;
        elsif p_new_status in ('PENDING_APPROVAL','REJECTED','DRAFT') then
            p_approved_by   := null;
            p_approved_date := null;
        end if;
    end apply_rules;

    function config_changes return xxfnd_config_change_tab pipelined is
        l_cur  sys_refcursor;
        l_rows xxfnd_config_change_tab;
    begin
        for v in (select distinct c.changes_view
                    from xxfnd_config_tables c
                   where c.approval_flag = 'Y' and c.changes_view is not null) loop
            begin
                open l_cur for 'select xxfnd_config_change_row(detail_pk, change_type, change_title, change_summary, '
                            || 'submitted_by, submitted_date) from ' || xxfnd_util_pkg.qualified(v.changes_view);
            exception
                when others then
                    -- a registered view that is not (yet) installed in this schema
                    continue;
            end;
            loop
                fetch l_cur bulk collect into l_rows limit 500;
                for i in 1 .. l_rows.count loop
                    pipe row (l_rows(i));
                end loop;
                exit when l_cur%notfound;
            end loop;
            close l_cur;
        end loop;
        return;
    end config_changes;

    ------------------------------------------------------------------------
    -- The approval task of a change
    ------------------------------------------------------------------------
    -- release 48: the rows behind an approval unit come from the registry (XXFND_CONFIG_TABLES): a table approved
    -- in units (UNIT_TABLE / UNIT_KEY_COLUMN, e.g. answer options of one question) or row by row.
    function registered(p_unit in varchar2) return xxfnd_config_tables%rowtype is
        l_row xxfnd_config_tables%rowtype;
    begin
        select * into l_row
          from xxfnd_config_tables
         where approval_flag = 'Y' and nvl(unit_table, table_name) = upper(p_unit)
           and rownum = 1;
        return l_row;
    exception
        when no_data_found then
            raise_application_error(-20124, p_unit || ' is not under maker-checker control.');
    end registered;

    function unit_rows(p_reg in xxfnd_config_tables%rowtype, p_key in varchar2, p_statuses in apex_t_varchar2)
        return apex_t_varchar2 is
        l_keys apex_t_varchar2;
    begin
        execute immediate 'select to_char(' || dbms_assert.simple_sql_name(p_reg.pk_column) || ') from '
                       || xxfnd_util_pkg.qualified(p_reg.table_name)
                       || ' where ' || dbms_assert.simple_sql_name(p_reg.unit_key_column) || ' = :k'
                       || ' and approval_status in (select column_value from table(:s))'
            bulk collect into l_keys using p_key, p_statuses;
        return l_keys;
    end unit_rows;

    procedure rows_of(p_detail_pk in varchar2, p_table out varchar2, p_keys out apex_t_varchar2) is
        l_unit varchar2(128) := substr(p_detail_pk, 1, instr(p_detail_pk, ':') - 1);
        l_key  varchar2(150) := substr(p_detail_pk, instr(p_detail_pk, ':') + 1);
        l_reg  xxfnd_config_tables%rowtype := registered(l_unit);
    begin
        p_table := l_reg.table_name;
        if l_reg.unit_table is not null then
            p_keys := unit_rows(l_reg, l_key, apex_t_varchar2('PENDING_APPROVAL'));
        else
            p_keys := apex_t_varchar2(l_key);
        end if;
    end rows_of;

    procedure request(p_table_name in varchar2, p_key in varchar2) is
        l_detail_pk varchar2(200) := upper(p_table_name) || ':' || p_key;
        l_type      varchar2(100);
        l_open      pls_integer;
        l_reg       xxfnd_config_tables%rowtype;
        l_keys      apex_t_varchar2;
        l_app       xxfnd_applications.application_code%type;
        l_wf        number;
    begin
        l_reg := registered(p_table_name);
        if l_reg.unit_table is not null then
            l_keys := unit_rows(l_reg, p_key, apex_t_varchar2('DRAFT', 'REJECTED'));
            for i in 1 .. l_keys.count loop
                submit(l_reg.table_name, l_keys(i));
            end loop;
        else
            submit(l_reg.table_name, p_key);
        end if;
        -- release 87 (C2): a CONFIG_CHANGE that faulted (e.g. after a cancel) is ended, so the change can be
        -- submitted again; a running one is kept
        for w in (select workflow_id from apex_workflows
                   where workflow_def_static_id = 'CONFIG_CHANGE' and detail_pk = l_detail_pk
                     and state_code = 'FAULTED') loop
            xxfnd_workflow_pkg.end_process(w.workflow_id);
        end loop;
        -- release 84: the change is approved in the COMMON workflow process CONFIG_CHANGE (one running per change)
        select count(*) into l_open
          from apex_workflows
         where workflow_def_static_id = 'CONFIG_CHANGE' and detail_pk = l_detail_pk
           and state_code in ('ACTIVE', 'SUSPENDED');
        if l_open = 0 then
            select max(change_type) into l_type from xxfnd_config_changes_v where detail_pk = l_detail_pk;
            if l_type is null then
                raise_application_error(-20125, 'There is nothing to approve for ' || l_detail_pk || '.');
            end if;
            select max(application_code) into l_app from xxfnd_applications where application_id = l_reg.application_id;
            l_wf := xxfnd_workflow_pkg.start_process(p_static_id        => 'CONFIG_CHANGE',
                                                     p_detail_pk        => l_detail_pk,
                                                     p_application_id   => xxfnd_workflow_pkg.common_application_id,
                                                     p_application_code => l_app);
        end if;
    end request;

    procedure approve_change(p_detail_pk in varchar2) is
        l_table varchar2(128);
        l_keys  apex_t_varchar2;
    begin
        xxfnd_vpd_pkg.begin_trusted;   -- release 84: the task action of the authorised approver
        if is_pending(p_detail_pk) = 'N' then
            raise_application_error(-20126, 'This change is no longer waiting for approval. Ask a workflow administrator to cancel the task.');
        end if;
        rows_of(p_detail_pk, l_table, l_keys);
        for i in 1 .. l_keys.count loop
            approve(l_table, l_keys(i));
        end loop;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end approve_change;

    procedure reject_change(p_detail_pk in varchar2, p_reason in varchar2) is
        l_table varchar2(128);
        l_keys  apex_t_varchar2;
    begin
        xxfnd_vpd_pkg.begin_trusted;   -- release 84: the task action of the authorised approver
        rows_of(p_detail_pk, l_table, l_keys);
        for i in 1 .. l_keys.count loop
            reject(l_table, l_keys(i), nvl(p_reason, 'Rejected by the approver.'));
        end loop;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end reject_change;

    function is_pending(p_detail_pk in varchar2) return varchar2 is
        l_count pls_integer;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select count(*) into l_count from xxfnd_config_changes_v where detail_pk = p_detail_pk;
        xxfnd_vpd_pkg.end_trusted;
        return case when l_count > 0 then 'Y' else 'N' end;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end is_pending;

    function task_change(p_task_id in number) return xxfnd_config_change_tab pipelined is
        l_pk   varchar2(4000) := xxfnd_workflow_pkg.task_record(p_task_id);
        l_rows xxfnd_config_change_tab;
    begin
        if l_pk is null then
            return;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select xxfnd_config_change_row(detail_pk, change_type, change_title, change_summary, submitted_by, submitted_date)
              bulk collect into l_rows
              from xxfnd_config_changes_v where detail_pk = l_pk;
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        for i in 1 .. l_rows.count loop
            pipe row (l_rows(i));
        end loop;
        return;
    end task_change;

    -- release 86: registration
    procedure register_config_table(p_application_code in varchar2,
                                    p_table_name       in varchar2,
                                    p_audit_flag       in varchar2 default 'Y',
                                    p_approval_flag    in varchar2 default 'N',
                                    p_pk_column        in varchar2 default null,
                                    p_unit_table       in varchar2 default null,
                                    p_unit_key_column  in varchar2 default null,
                                    p_changes_view     in varchar2 default null,
                                    p_description      in varchar2 default null) is
        l_code  xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);
        l_app   xxfnd_applications.application_id%type;
        l_n     pls_integer;
        l_owner xxfnd_applications.application_code%type;
    begin
        select application_id into l_app from xxfnd_applications where application_code = l_code;
        select count(*), max(a.application_code) into l_n, l_owner
          from xxfnd_config_tables c join xxfnd_applications a on a.application_id = c.application_id
         where c.table_name = upper(p_table_name);
        if l_n > 0 then
            xxfnd_application_pkg.assert_same_application('Configuration table', upper(p_table_name), l_owner, l_code);
            return;
        end if;
        insert into xxfnd_config_tables (table_name, application_id, audit_flag, approval_flag, pk_column, unit_table,
                                         unit_key_column, changes_view, description)
        values (upper(p_table_name), l_app, nvl(p_audit_flag, 'Y'), nvl(p_approval_flag, 'N'), upper(p_pk_column),
                upper(p_unit_table), upper(p_unit_key_column), upper(p_changes_view), p_description);
    end register_config_table;

end xxfnd_approval_pkg;
/
