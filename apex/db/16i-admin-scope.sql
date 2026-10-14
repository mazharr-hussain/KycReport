--------------------------------------------------------------------------------
-- 16i Administration scope (release 61). Installed by the COMMON application only (XXFUSION).
--   Each COMMON setup screen works for one application at a time (G_ADMIN_APP): it shows and changes only that
--   application's rows (and, for a Common Administrator, the shared rows: application empty).
--   - An application column on value sets, retention policies and storage rules (release 86: integration endpoints retired)
--     (the other setup tables already have one; empty = shared by all applications).
--   Release 73: no application filter for IT; delegated administration - an application's administrators open
--   the COMMON screens of the functions IT lets them manage, from their own application, for its rows only.
--   - Scope functions (release 80: XXFND_APPLICATION_PKG, 09d): the applications the signed-in user administers -
--     every application for a Common Administrator (role COMMON_ADMIN), otherwise the applications of the user's
--     active roles that hold an admin privilege.
-- Idempotent.
--------------------------------------------------------------------------------
-- application scope columns (empty = shared)
declare
    l_n pls_integer;
begin
    for t in (select column_value table_name
                from table(apex_t_varchar2('XXFND_VALUE_SETS', 'XXFND_RETENTION_POLICIES', 'XXFND_STORAGE_CONFIG'))) loop
        -- release 86: XXFND_INTEGRATION_ENDPOINTS retired (29); the servers (XXFND_SERVERS) are workspace-wide
        select count(*) into l_n from user_tab_columns where table_name = t.table_name and column_name = 'APPLICATION_CODE';
        if l_n = 0 then
            execute immediate 'alter table ' || t.table_name || ' add (application_code varchar2(30))';
        end if;
    end loop;
end;
/

comment on column xxfnd_value_sets.application_code            is 'Application the value set belongs to; empty = shared by all applications.';
comment on column xxfnd_retention_policies.application_code    is 'Application the policy belongs to; empty = shared by all applications.';
comment on column xxfnd_storage_config.application_code        is 'Application the storage rule belongs to; release 86: empty = COMMON (the instance), not a default for the other applications.';

-- release 80: the scope functions are in XXFND_APPLICATION_PKG (09d)

-- the scope on every setup table with an application column: policies + new rows belong to the application in scope
declare
    l_n pls_integer;
begin
    -- tables no longer scoped
    for p in (select object_name, policy_name from user_policies
               where policy_name like 'XXFND\_ADMIN\_SCOPE\_%' escape '\'
                 and object_name not in (select column_value from table(xxfnd_application_pkg.scoped_tables))) loop
        dbms_rls.drop_policy(object_schema => sys_context('USERENV', 'CURRENT_SCHEMA'),
                             object_name => p.object_name, policy_name => p.policy_name);
    end loop;
    for t in (select trigger_name from user_triggers
               where trigger_name like '%\_SC' escape '\'
                 and table_name not in (select column_value from table(xxfnd_application_pkg.scoped_tables))
                 and table_name like 'XXFND\_%' escape '\') loop
        execute immediate 'drop trigger ' || t.trigger_name;
    end loop;
    for t in (select column_value table_name from table(xxfnd_application_pkg.scoped_tables)) loop
        for p in (select 'XXFND_ADMIN_SCOPE_R' policy_name, 'POLICY_READ' fn, 'SELECT' stmts, false chk from dual
                  union all
                  select 'XXFND_ADMIN_SCOPE_C', 'POLICY_CHANGE', 'INSERT,UPDATE,DELETE', true from dual) loop
            -- release 80: a policy on the old package (XXFND_ADMIN_SCOPE_PKG) is re-created on XXFND_APPLICATION_PKG
            for o in (select policy_name from user_policies
                       where object_name = t.table_name and policy_name = p.policy_name
                         and nvl(package, '#') <> 'XXFND_APPLICATION_PKG') loop
                dbms_rls.drop_policy(object_schema => sys_context('USERENV', 'CURRENT_SCHEMA'),
                                     object_name => t.table_name, policy_name => o.policy_name);
            end loop;
            select count(*) into l_n from user_policies where object_name = t.table_name and policy_name = p.policy_name;
            if l_n = 0 then
                dbms_rls.add_policy(object_schema   => sys_context('USERENV', 'CURRENT_SCHEMA'),
                                    object_name     => t.table_name,
                                    policy_name     => p.policy_name,
                                    function_schema => sys_context('USERENV', 'CURRENT_SCHEMA'),
                                    policy_function => 'XXFND_APPLICATION_PKG.' || p.fn,
                                    statement_types => p.stmts,
                                    update_check    => p.chk,
                                    policy_type     => dbms_rls.context_sensitive);
            end if;
        end loop;
        execute immediate 'create or replace trigger ' || substr(t.table_name, 1, 120) || '_SC
            before insert on ' || t.table_name || '
            for each row
            when (new.application_code is null)
        begin
            -- release 61 (16i): a row created on a COMMON setup screen belongs to the application in scope
            if upper(v(''APP_ALIAS'')) = ''COMMON'' and nvl(upper(v(''G_ADMIN_APP'')), ''COMMON'') not in (''COMMON'', ''ALL'') then
                :new.application_code := upper(v(''G_ADMIN_APP''));
            end if;
        end;';
    end loop;
end;
/

-- release 80: XXFND_ADMIN_APPLICATIONS_V was not used by any page or package: dropped (checked, DDL recorded)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_ADMIN_APPLICATIONS_V', 'VIEW');
end;
/

