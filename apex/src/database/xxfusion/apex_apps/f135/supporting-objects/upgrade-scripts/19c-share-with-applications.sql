--------------------------------------------------------------------------------
-- 19c Sharing with the application schemas (release 54). COMMON only.
--   The shared XXFND_ objects exist only here (XXFUSION). Every application schema (XXFND_APPLICATIONS.SCHEMA_NAME,
--   e.g. KYC = XXCUS) gets grants on them and reaches them through synonyms, created by its own install
--   (KYC script 03). XXFND_SCHEMA_RELEASES and XXFND_DDL_PKG stay local to each schema (deployment tracking).
--   XXFND_SHARE_PKG:
--     grant_to / grant_to_applications - the grants (re-run on every install and upgrade: new objects too)
--     import_schema - one-time move of an application schema's own copy of the shared data into XXFUSION
--     seed_common   - the COMMON application's own access (role COMMON_ADMIN, feature COMMON_HOME, first admin)
--------------------------------------------------------------------------------
create or replace package xxfnd_share_pkg authid definer as
    -- Shared objects that stay local to each schema (never granted, never replaced by synonyms).
    function is_local(p_object_name in varchar2) return boolean;
    -- Tables: SELECT (with grant option, for the application's views), INSERT, UPDATE, DELETE, REFERENCES;
    -- views: SELECT; sequences: SELECT; packages, types, procedures, functions: EXECUTE.
    procedure grant_to(p_schema in varchar2);
    -- grant_to for the schema of every registered application that exists in this database.
    procedure grant_to_applications;
    -- One-time move: replaces the shared data here with the copy kept so far in p_schema (same keys, so the
    -- application's rows that refer to them stay valid), then re-applies seed_common. Every column of p_schema's
    -- tables must exist here, otherwise nothing is changed (-20140). Called by the application's install
    -- (KYC script 03) after it granted SELECT on its copy; recorded as release MOVE_<schema>, so it runs once.
    procedure import_schema(p_schema in varchar2);
    -- The COMMON application's own access and its first administrator (the installing developer).
    procedure seed_common;
end xxfnd_share_pkg;
/

create or replace package body xxfnd_share_pkg as

    function is_local(p_object_name in varchar2) return boolean is
    begin
        return upper(p_object_name) in ('XXFND_SCHEMA_RELEASES', 'XXFND_DDL_PKG');
    end is_local;

    procedure run(p_sql in varchar2) is
    begin
        execute immediate p_sql;
    exception
        when others then
            -- an invalid view cannot be granted; it is granted again on the next run
            dbms_output.put_line('skipped: ' || p_sql || ' - ' || sqlerrm);
    end run;

    procedure grant_to(p_schema in varchar2) is
        l_to varchar2(130) := dbms_assert.enquote_name(dbms_assert.schema_name(upper(p_schema)), false);
    begin
        for o in (select object_name, object_type from user_objects
                   where object_name like 'XXFND\_%' escape '\'
                     and object_type in ('TABLE', 'VIEW', 'SEQUENCE', 'PACKAGE', 'TYPE', 'PROCEDURE', 'FUNCTION')
                   order by object_type, object_name) loop
            continue when is_local(o.object_name);
            case o.object_type
                when 'TABLE' then
                    run('grant select on ' || o.object_name || ' to ' || l_to || ' with grant option');
                    run('grant insert, update, delete, references on ' || o.object_name || ' to ' || l_to);
                when 'VIEW' then
                    run('grant select on ' || o.object_name || ' to ' || l_to || ' with grant option');
                when 'SEQUENCE' then
                    run('grant select on ' || o.object_name || ' to ' || l_to);
                else
                    run('grant execute on ' || o.object_name || ' to ' || l_to);
            end case;
        end loop;
    end grant_to;

    procedure grant_to_applications is
    begin
        for a in (select distinct a.schema_name from xxfnd_applications a
                    join all_users u on u.username = a.schema_name
                   where a.schema_name <> $$PLSQL_UNIT_OWNER) loop
            grant_to(a.schema_name);
        end loop;
    end grant_to_applications;

    procedure seed_common is
        l_app   number;
        l_user  varchar2(255);
        l_name  varchar2(240);
        l_email varchar2(320);
    begin
    xxfnd_util_pkg.set_install_mode(true);
    select application_id into l_app from xxfnd_applications where application_code = 'COMMON';

    merge into xxfnd_roles t using (select 'COMMON_ADMIN' role_code from dual) s on (t.role_code = s.role_code)
     when not matched then insert (role_code, application_code, application_id, role_name, description)
                           values (s.role_code, 'COMMON', l_app, 'Common Administrator',
                                   'Maintains the setup every application shares: users and access, flexfields, attachments, workflow.');

    merge into xxfnd_features t using (select 'COMMON_HOME' feature_code from dual) s on (t.feature_code = s.feature_code)
     when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag, application_id)
                           values (s.feature_code, 'Common Home', 'BUSINESS', 10, 'N', l_app);
    merge into xxfnd_privileges t using (select 'COMMON_HOME.VIEW' privilege_code from dual) s
       on (t.privilege_code = s.privilege_code)
     when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                           values (s.privilege_code, 'COMMON_HOME', 'VIEW', 'Common Home - View');
    merge into xxfnd_feature_pages t using (select 'COMMON' app_alias, 1 page_id from dual) s
       on (t.app_alias = s.app_alias and t.page_id = s.page_id)
     when not matched then insert (app_alias, page_id, feature_code) values (s.app_alias, s.page_id, 'COMMON_HOME');
    merge into xxfnd_role_privileges t using (select 'COMMON_ADMIN' rc, 'COMMON_HOME.VIEW' pc from dual) s
       on (t.role_code = s.rc and t.privilege_code = s.pc)
     when not matched then insert (role_code, privilege_code) values (s.rc, s.pc);

    -- first administrator
    l_user := sys_context('APEX$SESSION', 'APP_USER');
    if l_user is not null then
        begin
            execute immediate q'[
                select max(trim(u.first_name || ' ' || u.last_name)), max(u.email)
                  from apex_workspace_apex_users u
                 where upper(u.user_name) = upper(:1)]'
                into l_name, l_email using l_user;
        exception
            when others then
                null;
        end;
        xxfnd_security_pkg.bootstrap_admin(l_user, l_name, l_email, 'COMMON_ADMIN');
    else
        for a in (select user_name, trim(first_name || ' ' || last_name) full_name, email
                    from apex_workspace_apex_users
                   where is_admin = 'Yes' and nvl(account_locked, 'No') = 'No') loop
            xxfnd_security_pkg.bootstrap_admin(a.user_name, a.full_name, a.email, 'COMMON_ADMIN');
        end loop;
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    exception
        when others then
            xxfnd_util_pkg.set_install_mode(false);
            raise;
    end seed_common;

    procedure import_schema(p_schema in varchar2) is
        l_src     varchar2(128) := upper(dbms_assert.schema_name(upper(p_schema)));
        l_release varchar2(30)  := substr('MOVE_' || l_src, 1, 30);
        l_missing varchar2(4000);
        l_cols    varchar2(32767);
        l_src_n   number;
        l_dst_n   number;
        l_max     number;
        cursor c_tables is
            select t.table_name from all_tables t
             where t.owner = l_src and t.table_name like 'XXFND\_%' escape '\'
               and t.table_name <> 'XXFND_SCHEMA_RELEASES'
             order by t.table_name;
        procedure switch(p_on in boolean) is
        begin
            for c in (select table_name, constraint_name from user_constraints
                       where constraint_type = 'R' and table_name like 'XXFND\_%' escape '\') loop
                execute immediate 'alter table ' || c.table_name || case when p_on then ' enable' else ' disable' end
                               || ' constraint ' || c.constraint_name;
            end loop;
            for t in (select table_name from user_tables where table_name like 'XXFND\_%' escape '\') loop
                execute immediate 'alter table ' || t.table_name || case when p_on then ' enable' else ' disable' end
                               || ' all triggers';
            end loop;
        end switch;
    begin
        if xxfnd_ddl_pkg.release_applied(l_release) then
            return;   -- moved before
        end if;
        -- every table and column of the source must exist here
        for c in (select s.table_name, s.column_name from all_tab_columns s
                   where s.owner = l_src and s.table_name like 'XXFND\_%' escape '\'
                     and s.table_name <> 'XXFND_SCHEMA_RELEASES'
                     and s.table_name in (select table_name from all_tables where owner = l_src)
                     and not exists (select 1 from user_tab_columns d
                                      where d.table_name = s.table_name and d.column_name = s.column_name)
                   order by 1, 2) loop
            l_missing := substr(l_missing || ' ' || c.table_name || '.' || c.column_name, 1, 3000);
        end loop;
        if l_missing is not null then
            raise_application_error(-20140, 'The shared data of ' || l_src || ' was not moved: these columns are missing in '
                || $$PLSQL_UNIT_OWNER || ' (install the latest COMMON application first):' || l_missing);
        end if;

        xxfnd_vpd_pkg.begin_trusted;
        switch(false);
        begin
            -- this schema's rows of the moved tables (until now only the COMMON install's seed) make way
            for t in c_tables loop
                execute immediate 'delete from ' || t.table_name;
            end loop;
            for t in c_tables loop
                select listagg(column_name, ', ') within group (order by column_id) into l_cols
                  from all_tab_columns where owner = l_src and table_name = t.table_name;
                execute immediate 'insert into ' || t.table_name || ' (' || l_cols || ') select ' || l_cols
                               || ' from ' || dbms_assert.enquote_name(l_src, false) || '.' || t.table_name;
                execute immediate 'select count(*) from ' || dbms_assert.enquote_name(l_src, false) || '.' || t.table_name
                    into l_src_n;
                execute immediate 'select count(*) from ' || t.table_name into l_dst_n;
                if l_src_n <> l_dst_n then
                    raise_application_error(-20141, t.table_name || ': ' || l_src_n || ' rows in ' || l_src || ', '
                                                    || l_dst_n || ' copied.');
                end if;
            end loop;
        exception
            when others then
                rollback;
                switch(true);
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        commit;
        switch(true);
        xxfnd_vpd_pkg.end_trusted;

        -- new keys continue after the moved ones
        for c in (select table_name, column_name from user_tab_identity_cols
                   where table_name like 'XXFND\_%' escape '\') loop
            execute immediate 'alter table ' || c.table_name || ' modify ' || c.column_name
                           || ' generated by default on null as identity (start with limit value)';
        end loop;
        select nvl(max(application_id), 999) + 1 into l_max from xxfnd_applications;
        execute immediate 'alter sequence xxfnd_applications_s restart start with ' || greatest(l_max, 1000);

        -- the moved registry: each application's schema, then this application's own access
        update xxfnd_applications set schema_name = $$PLSQL_UNIT_OWNER where application_code = 'COMMON';
        update xxfnd_applications set schema_name = l_src
         where application_code in (select application_code from xxfnd_applications where schema_name is null
                                       and application_code <> 'COMMON');
        seed_common;
        xxfnd_ddl_pkg.mark_release(l_release, 'Shared data moved from ' || l_src);
        commit;
    end import_schema;

end xxfnd_share_pkg;
/

-- every application schema can reach the shared objects (new objects of this release too)
begin
    xxfnd_share_pkg.grant_to_applications;
end;
/
