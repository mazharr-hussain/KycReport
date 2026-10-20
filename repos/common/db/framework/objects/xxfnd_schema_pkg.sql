--------------------------------------------------------------------------------
-- 03_xxfnd_core_pkgs.sql
--   XXFND_UTIL_PKG      session user/language, WHO-trigger generator (release 80: lookups in XXFND_LOOKUP_PKG, 05c)
--   XXFND_AUDIT_PKG     change reason + audit-trigger generator
--   (XXFND_SECURITY_PKG until release 78: its parts moved to XXFND_USER_PKG 16j, XXFND_PRIVILEGE_PKG 09b and
--    XXFND_INTEGRATION_PKG 05b)
--   XXFND_APPROVAL_PKG  maker-checker for configuration changes
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- release 54: generators that create triggers and data security policies in the schema of the CALLER
-- (invoker rights). The shared objects live in XXFUSION; an application schema (XXCUS) reaches this
-- package through its synonym and the triggers / policies are created on its own tables.
-- XXFND_UTIL_PKG / XXFND_AUDIT_PKG / XXFND_VPD_PKG keep their generator procedures for XXFUSION itself.
--------------------------------------------------------------------------------
create or replace package xxfnd_schema_pkg authid current_user as
    -- WHO-column trigger (CREATED_BY ... OBJECT_VERSION_NUMBER) on a table of the caller's schema.
    procedure create_who_trigger(p_table_name in varchar2);
    -- WHO triggers on every XXFND_/XXCMP_ table of the caller's schema that has the WHO columns.
    procedure create_all_who_triggers;
    -- Audit trigger: one XXFND_AUDIT_LOG row per changed column (updates) or per record (inserts, deletes).
    procedure create_audit_trigger(p_table_name in varchar2);
    -- Audit triggers on the caller's tables registered with AUDIT_FLAG = Y (XXFND_CONFIG_TABLES).
    procedure create_config_audit_triggers;
    -- Data security: the policy XXFND_VPD_PKG.POLICY on every table of the caller's schema that has a rule
    -- (XXFND_DATA_SECURITY_RULES); a policy pointing to another function owner is replaced.
    procedure apply_policies;
end xxfnd_schema_pkg;
/

create or replace package body xxfnd_schema_pkg as
    c_policy constant varchar2(30) := 'XXFND_DATA_SECURITY';

    procedure create_who_trigger(p_table_name in varchar2) is
        l_table varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_trg   varchar2(128) := substr(l_table, 1, 124) || '_WHO';
    begin
        execute immediate
            'create or replace trigger ' || l_trg || '
                before insert or update on ' || l_table || '
                for each row
             begin
                 if inserting then
                     :new.created_by    := nvl(:new.created_by, xxfnd_util_pkg.current_user);
                     :new.creation_date := nvl(:new.creation_date, systimestamp);
                     :new.object_version_number := 1;
                 elsif xxfnd_util_pkg.preserve_who then
                     -- a user rename: only the user names change
                     :new.creation_date         := :old.creation_date;
                     :new.last_update_date      := :old.last_update_date;
                     :new.last_update_login     := :old.last_update_login;
                     :new.object_version_number := :old.object_version_number;
                     return;
                 else
                     :new.created_by    := :old.created_by;
                     :new.creation_date := :old.creation_date;
                     :new.object_version_number := nvl(:old.object_version_number, 0) + 1;
                 end if;
                 :new.last_updated_by   := xxfnd_util_pkg.current_user;
                 :new.last_update_date  := systimestamp;
                 :new.last_update_login := sys_context(''APEX$SESSION'', ''APP_SESSION'');
             end;';
    end create_who_trigger;

    procedure create_all_who_triggers is
    begin
        for t in (select c.table_name
                    from user_tab_columns c
                    join user_tables tb on tb.table_name = c.table_name
                   where (c.table_name like 'XXFND\_%' escape '\' or c.table_name like 'XXHR\_%' escape '\'
                          or c.table_name like 'XXCMP\_%' escape '\')
                     and c.column_name = 'OBJECT_VERSION_NUMBER'
                   order by c.table_name)
        loop
            create_who_trigger(t.table_name);
        end loop;
    end create_all_who_triggers;

    function col_to_char(p_ref in varchar2, p_data_type in varchar2) return varchar2 is
    begin
        return case
                 when p_data_type like 'TIMESTAMP%' then 'to_char(' || p_ref || ', ''YYYY-MM-DD HH24:MI:SS.FF'')'
                 when p_data_type = 'DATE'          then 'to_char(' || p_ref || ', ''YYYY-MM-DD HH24:MI:SS'')'
                 when p_data_type = 'NUMBER'        then 'to_char(' || p_ref || ', ''TM9'')'
                 else p_ref
               end;
    end col_to_char;

    procedure create_audit_trigger(p_table_name in varchar2) is
        l_table varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_trg   varchar2(128) := substr(l_table, 1, 124) || '_AUD';
        l_pk_new varchar2(4000);
        l_pk_old varchar2(4000);
        l_body  clob;
    begin
        for c in (select cc.column_name
                    from user_constraints uc
                    join user_cons_columns cc on cc.constraint_name = uc.constraint_name
                   where uc.table_name = l_table
                     and uc.constraint_type = 'P'
                   order by cc.position)
        loop
            l_pk_new := l_pk_new || case when l_pk_new is not null then ' || ''|'' || ' end || 'to_char(:new.' || c.column_name || ')';
            l_pk_old := l_pk_old || case when l_pk_old is not null then ' || ''|'' || ' end || 'to_char(:old.' || c.column_name || ')';
        end loop;
        if l_pk_new is null then
            raise_application_error(-20101, l_table || ' has no primary key; cannot generate audit trigger.');
        end if;

        l_body := 'create or replace trigger ' || l_trg || '
            after insert or update or delete on ' || l_table || '
            for each row
            declare
                l_pk varchar2(400);
            begin
                if inserting then
                    xxfnd_audit_pkg.log_change(''' || l_table || ''', ' || l_pk_new || ', ''I'');
                    return;
                elsif deleting then
                    xxfnd_audit_pkg.log_change(''' || l_table || ''', ' || l_pk_old || ', ''D'');
                    return;
                end if;
                l_pk := ' || l_pk_new || ';
';
        for c in (select column_name, data_type
                    from user_tab_columns
                   where table_name = l_table
                     and data_type not in ('CLOB','BLOB','NCLOB','LONG','LONG RAW','RAW','JSON')
                     and column_name not in ('CREATED_BY','CREATION_DATE','LAST_UPDATED_BY',
                                             'LAST_UPDATE_DATE','LAST_UPDATE_LOGIN','OBJECT_VERSION_NUMBER')
                   order by column_id)
        loop
            l_body := l_body || '
                if (:old.' || c.column_name || ' <> :new.' || c.column_name || ')
                   or (:old.' || c.column_name || ' is null and :new.' || c.column_name || ' is not null)
                   or (:old.' || c.column_name || ' is not null and :new.' || c.column_name || ' is null) then
                    xxfnd_audit_pkg.log_change(''' || l_table || ''', l_pk, ''U'', ''' || c.column_name || ''',
                        ' || col_to_char(':old.' || c.column_name, c.data_type) || ',
                        ' || col_to_char(':new.' || c.column_name, c.data_type) || ');
                end if;';
        end loop;
        l_body := l_body || '
            end;';
        execute immediate l_body;
    end create_audit_trigger;

    procedure create_config_audit_triggers is
    begin
        -- the configuration tables each application registered (XXFND_CONFIG_TABLES), in the caller's schema
        for t in (select c.table_name
                    from xxfnd_config_tables c
                    join user_tables u on u.table_name = c.table_name
                   where c.audit_flag = 'Y'
                   order by c.table_name) loop
            create_audit_trigger(t.table_name);
        end loop;
    end create_config_audit_triggers;

    procedure apply_policies is
        type t_names is table of varchar2(128);
        l_owner  varchar2(128);
        l_tables t_names;
    begin
        -- release 59: dynamic, because the rules table (script 09b) is created after this package
        execute immediate 'select distinct d.table_name from xxfnd_data_security_rules d '
                       || 'join user_tables u on u.table_name = d.table_name'
            bulk collect into l_tables;
        for i in 1 .. l_tables.count loop
            select max(pf_owner) into l_owner from user_policies
             where object_name = l_tables(i) and policy_name = c_policy;
            if l_owner is not null and l_owner <> $$PLSQL_UNIT_OWNER then
                dbms_rls.drop_policy(object_schema => sys_context('USERENV', 'CURRENT_SCHEMA'),
                                     object_name   => l_tables(i), policy_name => c_policy);
                l_owner := null;
            end if;
            if l_owner is null then
                dbms_rls.add_policy(
                    object_schema   => sys_context('USERENV', 'CURRENT_SCHEMA'),
                    object_name     => l_tables(i),
                    policy_name     => c_policy,
                    function_schema => $$PLSQL_UNIT_OWNER,
                    policy_function => 'XXFND_VPD_PKG.POLICY',
                    statement_types => 'SELECT,INSERT,UPDATE,DELETE',
                    update_check    => true,
                    policy_type     => dbms_rls.dynamic);
            end if;
        end loop;
    end apply_policies;

end xxfnd_schema_pkg;
/
