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
        execute immediate 'update ' || dbms_assert.sql_object_name(upper(p_table_name))
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
                            || 'submitted_by, submitted_date) from ' || dbms_assert.sql_object_name(v.changes_view);
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

end xxfnd_approval_pkg;
/
