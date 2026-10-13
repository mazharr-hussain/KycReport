-- Upgrade fix: partial unique indexes were created as (column, ..., CASE ... END), which also
-- restricted rows outside the condition (ORA-00001 in the seed data). Recreate any index that
-- still has a plain column with every key column inside the CASE. Existing data always fits.
declare
    procedure fix(p_index in varchar2, p_definition in varchar2) is
        l_old pls_integer;
    begin
        select count(*) into l_old from user_ind_columns
         where index_name = p_index and column_name not like 'SYS\_NC%' escape '\';
        if l_old > 0 then
            execute immediate 'drop index ' || p_index;
            execute immediate 'create unique index ' || p_index || ' on ' || p_definition;
        end if;
    end fix;
begin
    fix('XXFND_USER_ROLES_U1', 'xxfnd_user_roles (case when end_date_active is null then employee_id end, case when end_date_active is null then role_code end)');
    fix('XXFND_DF_CONTEXTS_U1', 'xxfnd_df_contexts (case when global_flag = ''Y'' then descriptive_flexfield_code end)');
    -- (XXCMP_PARTY_CONTACTS_U1 became one primary contact person per party in release 23: 16f)
end;
/

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
                   where (c.table_name like 'XXFND\_%' escape '\' or c.table_name like 'XXCMP\_%' escape '\')
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

create or replace package xxfnd_util_pkg authid definer as
    -- Signed-in APEX user, or the database user outside APEX (install, jobs).
    function current_user return varchar2;
    -- Session language as an APEX language code ('en', 'ar'); defaults to 'en'.
    function current_lang return varchar2;
    function in_apex_session return boolean;
    -- Install mode: seed scripts run inside an APEX session when installed as
    -- Supporting Objects; this makes the session count as "not APEX" so seeded
    -- rows are not treated as user edits (maker-checker, lookup locks).
    procedure set_install_mode(p_on in boolean);
    -- On while user names are renamed (xxfnd_user_pkg.rename_user): the WHO triggers keep the dates and
    -- version of the rows and accept the new user names in CREATED_BY / LAST_UPDATED_BY.
    procedure set_preserve_who(p_on in boolean);
    function preserve_who return boolean;

    -- Replace #TOKEN# placeholders from a JSON object {"TOKEN":"value",...}.
    function replace_tokens(p_text in clob, p_tokens_json in clob) return clob;

    -- WHO-column trigger: fills CREATED_BY/CREATION_DATE/LAST_UPDATED_BY/
    -- LAST_UPDATE_DATE/LAST_UPDATE_LOGIN and increments OBJECT_VERSION_NUMBER.
    procedure create_who_trigger(p_table_name in varchar2);
    -- Creates WHO triggers on every XXFND_/XXCMP_ table that has the WHO columns.
    procedure create_all_who_triggers;

    -- release 54: owner of a table, view or package this schema can see - itself first, else the application
    -- schema that granted it (KYC objects in XXCUS); raises -20130 when there is none.
    function object_owner(p_name in varchar2) return varchar2;
    -- "OWNER"."NAME" of that object, for dynamic SQL.
    function qualified(p_name in varchar2) return varchar2;
end xxfnd_util_pkg;
/

create or replace package body xxfnd_util_pkg as

    g_install_mode boolean := false;
    g_preserve_who boolean := false;

    procedure set_install_mode(p_on in boolean) is
    begin
        g_install_mode := nvl(p_on, false);
    end set_install_mode;

    procedure set_preserve_who(p_on in boolean) is
    begin
        g_preserve_who := nvl(p_on, false);
    end set_preserve_who;

    function preserve_who return boolean is
    begin
        return g_preserve_who;
    end preserve_who;

    function in_apex_session return boolean is
    begin
        return not g_install_mode and sys_context('APEX$SESSION', 'APP_USER') is not null;
    end in_apex_session;

    function current_user return varchar2 is
    begin
        return coalesce(sys_context('APEX$SESSION', 'APP_USER'),
                        sys_context('USERENV', 'SESSION_USER'));
    end current_user;

    function current_lang return varchar2 is
        l_lang varchar2(30);
    begin
        if in_apex_session then
            begin
                l_lang := lower(apex_util.get_session_lang);
            exception
                when others then l_lang := null;
            end;
        end if;
        -- Normalise regional variants ('en-us' -> 'en') to match seeded rows.
        return nvl(regexp_substr(l_lang, '^[a-z]+'), 'en');
    end current_lang;

    -- Result-cached per type, code and language: report queries call LOOKUP_MEANING for every row and column.
    -- Oracle invalidates the cache when XXFND_LOOKUP_VALUES(_TL) change.
    function replace_tokens(p_text in clob, p_tokens_json in clob) return clob is
        l_result clob := p_text;
        l_obj    json_object_t;
        l_keys   json_key_list;
    begin
        if p_text is null or p_tokens_json is null then
            return p_text;
        end if;
        l_obj  := json_object_t.parse(p_tokens_json);
        l_keys := l_obj.get_keys;
        for i in 1 .. l_keys.count loop
            l_result := replace(l_result, '#' || upper(l_keys(i)) || '#', l_obj.get_string(l_keys(i)));
        end loop;
        return l_result;
    end replace_tokens;

    procedure create_who_trigger(p_table_name in varchar2) is
    begin
        xxfnd_schema_pkg.create_who_trigger(p_table_name);
    end create_who_trigger;

    procedure create_all_who_triggers is
    begin
        xxfnd_schema_pkg.create_all_who_triggers;
    end create_all_who_triggers;

    function object_owner(p_name in varchar2) return varchar2 is
        l_owner varchar2(128);
    begin
        select max(owner) keep (dense_rank first order by case when owner = $$PLSQL_UNIT_OWNER then 0 else 1 end, owner)
          into l_owner
          from all_objects
         where object_name = upper(p_name) and object_type in ('TABLE', 'VIEW', 'PACKAGE');
        if l_owner is null then
            raise_application_error(-20130, p_name || ' does not exist or is not granted to ' || $$PLSQL_UNIT_OWNER || '.');
        end if;
        return l_owner;
    end object_owner;

    function qualified(p_name in varchar2) return varchar2 is
    begin
        return dbms_assert.enquote_name(object_owner(p_name), false) || '.'
            || dbms_assert.enquote_name(upper(dbms_assert.simple_sql_name(p_name)), false);
    end qualified;

end xxfnd_util_pkg;
/

--------------------------------------------------------------------------------
create or replace package xxfnd_audit_pkg authid definer as
    -- Set before a save to record why a configuration value changed (FR-36).
    procedure set_change_reason(p_reason in varchar2);
    function  get_change_reason return varchar2;
    procedure clear_change_reason;

    procedure log_change(p_table_name in varchar2,
                         p_pk_value   in varchar2,
                         p_action     in varchar2,
                         p_column     in varchar2 default null,
                         p_old_value  in varchar2 default null,
                         p_new_value  in varchar2 default null);

    -- Generates an AFTER INSERT/UPDATE/DELETE row trigger that writes one row
    -- per changed column (updates) or one row per record (inserts, deletes).
    -- WHO columns and LOB columns are skipped.
    procedure create_audit_trigger(p_table_name in varchar2);
    procedure create_config_audit_triggers;
end xxfnd_audit_pkg;
/

create or replace package body xxfnd_audit_pkg as
    g_reason varchar2(1000);

    procedure set_change_reason(p_reason in varchar2) is
    begin
        g_reason := substr(p_reason, 1, 1000);
    end set_change_reason;

    function get_change_reason return varchar2 is
    begin
        return g_reason;
    end get_change_reason;

    procedure clear_change_reason is
    begin
        g_reason := null;
    end clear_change_reason;

    procedure log_change(p_table_name in varchar2,
                         p_pk_value   in varchar2,
                         p_action     in varchar2,
                         p_column     in varchar2 default null,
                         p_old_value  in varchar2 default null,
                         p_new_value  in varchar2 default null) is
    begin
        insert into xxfnd_audit_log
            (table_name, pk_value, action_code, column_name, old_value, new_value, change_reason, changed_by)
        values
            (p_table_name, p_pk_value, p_action, p_column,
             substr(p_old_value, 1, 4000), substr(p_new_value, 1, 4000),
             g_reason, xxfnd_util_pkg.current_user);
    end log_change;

    procedure create_audit_trigger(p_table_name in varchar2) is
    begin
        xxfnd_schema_pkg.create_audit_trigger(p_table_name);
    end create_audit_trigger;

    procedure create_config_audit_triggers is
    begin
        xxfnd_schema_pkg.create_config_audit_triggers;
    end create_config_audit_triggers;

end xxfnd_audit_pkg;
/

--------------------------------------------------------------------------------

-- release 46: grants belong to the user (XXFND_USERS); an SSO user is linked to an employee, a LOCAL user is not
create or replace view xxfnd_user_roles_v as
select ur.user_role_id,
       u.user_id,
       u.employee_id,
       u.user_name,
       coalesce(e.full_name, u.full_name, u.user_name) full_name,
       nvl(e.source_type, 'LOCAL') source_type,
       u.user_type,
       ur.role_code,
       r.role_name,
       r.application_code,
       r.application_id,
       ur.start_date_active,
       ur.end_date_active,
       ur.enabled_flag,
       case when ur.enabled_flag = 'Y' and r.enabled_flag = 'Y' and u.enabled_flag = 'Y'
             and trunc(sysdate) between ur.start_date_active and nvl(ur.end_date_active, trunc(sysdate))
             and trunc(sysdate) between u.start_date_active  and nvl(u.end_date_active,  trunc(sysdate))
             and (e.employee_id is null
                  or (e.enabled_flag = 'Y' and trunc(sysdate) between e.start_date_active and nvl(e.end_date_active, trunc(sysdate))))
            then 'Y' else 'N' end active_flag
  from xxfnd_user_roles ur
  join xxfnd_users u          on u.user_id     = ur.user_id
  left join xxfnd_employees e on e.employee_id = u.employee_id
  join xxfnd_roles r          on r.role_code   = ur.role_code;


--------------------------------------------------------------------------------
create or replace package xxfnd_approval_pkg authid definer as
    -- Tables under maker-checker control.
    function is_controlled(p_table_name in varchar2) return boolean;

    procedure submit(p_table_name in varchar2, p_pk_value in varchar2);
    procedure approve(p_table_name in varchar2, p_pk_value in varchar2);
    procedure reject(p_table_name in varchar2, p_pk_value in varchar2, p_reason in varchar2);

    -- Called from the BEFORE UPDATE/INSERT trigger on each controlled table.
    -- Editing an approved row sends it back for approval; approving your own
    -- change is refused.
    procedure apply_rules(p_inserting        in boolean,
                          p_old_status       in varchar2,
                          p_new_status       in out varchar2,
                          p_old_last_updated in varchar2,
                          p_approved_by      in out varchar2,
                          p_approved_date    in out timestamp);

    -- release 48: the pending changes of every application, one row per approval unit, from the views the
    -- applications registered (XXFND_CONFIG_TABLES.CHANGES_VIEW). Read through XXFND_CONFIG_CHANGES_V.
    function config_changes return xxfnd_config_change_tab pipelined;
    -- release 74 (one package per component): the approval task of a change (was XXFND_CONFIG_APPROVAL_PKG).
    -- Submits a change for approval and creates its CONFIG_CHANGE approval task (one open task per change).
    -- P_TABLE_NAME / P_KEY: a registered maker-checker table and its key, or a unit table and its key for all draft
    -- or rejected rows of that unit (XXFND_CONFIG_TABLES, e.g. XXCMP_QUESTIONS / question id = its answer options).
    procedure request(p_table_name in varchar2, p_key in varchar2);
    -- Task actions (the approver's session): apply or reject every row of the change.
    procedure approve_change(p_detail_pk in varchar2);
    procedure reject_change(p_detail_pk in varchar2, p_reason in varchar2);
    -- Y while the change behind a task is still waiting for approval.
    function is_pending(p_detail_pk in varchar2) return varchar2;
end xxfnd_approval_pkg;
/
