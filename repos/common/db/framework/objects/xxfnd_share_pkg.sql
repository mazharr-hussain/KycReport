--------------------------------------------------------------------------------
-- 19c Sharing with the application schemas (release 54). COMMON only.
--   The shared XXFND_ objects exist only here (XXFUSION). Every application schema (XXFND_APPLICATIONS.SCHEMA_NAME,
--   e.g. KYC = XXCUS) gets grants on them and reaches them through synonyms, created by its own install
--   (KYC script 03). XXFND_SCHEMA_RELEASES and XXFND_DDL_PKG stay local to each schema (deployment tracking).
--   XXFND_SHARE_PKG:
--     grant_to / grant_to_applications - the grants (re-run on every install and upgrade: new objects too)
--     import_schema - one-time move of an application schema's own copy of the shared data into XXFUSION
--     seed_common   - the COMMON application's own access (role COMMON_ADMIN, feature COMMON_HOME, first admin)
--     grant_onboarding (release 87) - EXECUTE on XXFND_ONBOARD_PKG to the workspace's schemas; the grants run last
--       (script 99, C11)
--------------------------------------------------------------------------------
create or replace package xxfnd_share_pkg authid definer as
    -- Shared objects that stay local to each schema (never granted, never replaced by synonyms).
    function is_local(p_object_name in varchar2) return boolean;
    -- Tables: SELECT (with grant option, for the application's views) and REFERENCES (release 88: no INSERT, UPDATE or
    -- DELETE - data changes only through the COMMON routines; an earlier grant is taken back);
    -- views: SELECT; sequences: SELECT; packages, types, procedures, functions: EXECUTE.
    procedure grant_to(p_schema in varchar2);
    -- grant_to for the schema of every registered application that exists in this database.
    procedure grant_to_applications;
    -- release 87: EXECUTE on XXFND_ONBOARD_PKG to every schema of COMMON's workspace, so an application's own install
    -- can register it (generic script 00c); everything else is granted only once the application is registered.
    procedure grant_onboarding;
    -- One-time move: replaces the shared data here with the copy kept so far in p_schema (same keys, so the
    -- application's rows that refer to them stay valid), then re-applies seed_common. Every column of p_schema's
    -- tables must exist here, otherwise nothing is changed (-20140). Called by the application's install
    -- (KYC script 03) after it granted SELECT on its copy; recorded as release MOVE_<schema>, so it runs once.
    procedure import_schema(p_schema in varchar2);
    -- The COMMON application's own access and its first administrator (the installing developer).
    procedure seed_common;
    -- release 61: the COMMON administration seed (admin features, COMMON pages, Common Administrator privileges).
    procedure seed_admin;
end xxfnd_share_pkg;
/

create or replace package body xxfnd_share_pkg as

    function is_local(p_object_name in varchar2) return boolean is
    begin
        -- release 73: the setup forms' table / column lists read ALL_TABLES (not grantable on); COMMON's own
        -- release 86: the server and storage views read APEX metadata (not grantable on); COMMON's own screens only
        return upper(p_object_name) in ('XXFND_SCHEMA_RELEASES', 'XXFND_DDL_PKG', 'XXFND_SETUP_TABLES_V', 'XXFND_SETUP_COLUMNS_V',
                                        'XXFND_SERVERS_V', 'XXFND_APP_STORAGE_V');
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
            -- release 76 (S-03, A-08): COMMON only - the error log (written by XXFND_ERROR_PKG, read by IT in COMMON)
            -- is not granted to the applications, and an earlier grant is taken back
            if o.object_name in ('XXFND_ERROR_LOG') then
                run('revoke all on ' || o.object_name || ' from ' || l_to);
                continue;
            end if;
            case o.object_type
                when 'TABLE' then
                    run('grant select on ' || o.object_name || ' to ' || l_to || ' with grant option');
                    -- release 88 (C10): data in COMMON changes only through COMMON routines (EXECUTE): no INSERT,
                    -- UPDATE or DELETE for the applications, an earlier grant is taken back; REFERENCES stays (the
                    -- applications' foreign keys to COMMON keys, it changes no data)
                    run('grant references on ' || o.object_name || ' to ' || l_to);
                    for w in (select privilege from user_tab_privs_made
                               where grantee = upper(p_schema) and table_name = o.object_name
                                 and privilege in ('INSERT', 'UPDATE', 'DELETE')) loop
                        run('revoke ' || w.privilege || ' on ' || o.object_name || ' from ' || l_to);
                    end loop;
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

    procedure grant_onboarding is
        l_ws varchar2(255);
    begin
        select max(workspace) into l_ws from apex_applications
         where application_id = (select apex_application_id from xxfnd_applications where application_code = 'COMMON');
        if l_ws is null then
            return;
        end if;
        for w in (select schema from apex_workspace_schemas where workspace_name = l_ws and schema <> $$PLSQL_UNIT_OWNER) loop
            run('grant execute on xxfnd_onboard_pkg to ' || dbms_assert.enquote_name(w.schema, false));
        end loop;
    end grant_onboarding;

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
    -- release 74: Common administrators see every common RFI (15c) and e-mail (15e); each application adds its own
    -- roles' rules. Here, after the role exists (a fresh install runs 15c / 15e before the role is created).
    merge into xxfnd_data_security_rules t
    using (select 'XXFND_RFIS' tb from dual union all select 'XXFND_COMMUNICATIONS' from dual) s
       on (t.role_code = 'COMMON_ADMIN' and t.table_name = s.tb and t.rule_type = 'ALL_ROWS')
     when not matched then insert (role_code, table_name, rule_type) values ('COMMON_ADMIN', s.tb, 'ALL_ROWS');
    commit;
    xxfnd_schema_pkg.apply_policies;

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
        xxfnd_user_pkg.bootstrap_admin(l_user, l_name, l_email, 'COMMON_ADMIN');
    else
        for a in (select user_name, trim(first_name || ' ' || last_name) full_name, email
                    from apex_workspace_apex_users
                   where is_admin = 'Yes' and nvl(account_locked, 'No') = 'No') loop
            xxfnd_user_pkg.bootstrap_admin(a.user_name, a.full_name, a.email, 'COMMON_ADMIN');
        end loop;
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    exception
        when others then
            xxfnd_util_pkg.set_install_mode(false);
            raise;
    end seed_common;

    -- release 61: the admin features, the COMMON pages and tabs, every admin privilege for the Common Administrator
    -- (script 21; again after an application's shared data was moved here, import_schema)
    procedure seed_admin is
        c_amp constant varchar2(1) := chr(38);   -- no literal ampersand: script runners substitute it
        l_app number;

        procedure feature(p_code in varchar2, p_name in varchar2, p_group in varchar2, p_seq in number, p_actions in varchar2,
                          p_home in number, p_icon in varchar2, p_description in varchar2) is
        begin
            merge into xxfnd_features t using (select p_code c from dual) s on (t.feature_code = s.c)
             when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag,
                                           application_id, home_page_id, icon_css, description)
                                   values (p_code, p_name, p_group, p_seq, 'Y', l_app, p_home, p_icon, p_description);
            for a in (select column_value action from table(apex_string.split(p_actions, ','))) loop
                merge into xxfnd_privileges t using (select p_code || '.' || a.action pc from dual) s
                   on (t.privilege_code = s.pc)
                 when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                                       values (s.pc, p_code, a.action, p_name || ' - ' || initcap(a.action));
            end loop;
        end feature;

        -- pages of a feature: 'page=Tab label|page|...' (a label makes the page a tab of the feature)
        procedure pages(p_feature in varchar2, p_pages in varchar2) is
            l_seq   pls_integer := 0;
            l_page  number;
            l_label varchar2(100);
        begin
            for t in (select column_value item from table(apex_string.split(p_pages, '|'))) loop
                l_page  := to_number(regexp_substr(t.item, '^[0-9]+'));
                l_label := case when instr(t.item, '=') > 0 then substr(t.item, instr(t.item, '=') + 1) end;
                if l_label is not null then
                    l_seq := l_seq + 10;
                end if;
                merge into xxfnd_feature_pages d
                using (select 'COMMON' app_alias, l_page page_id from dual) s
                   on (d.app_alias = s.app_alias and d.page_id = s.page_id)
                 when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                                       values ('COMMON', l_page, p_feature, l_label,
                                               case when l_label is not null then l_seq end);
            end loop;
        end pages;
    begin
        xxfnd_util_pkg.set_install_mode(true);
        select application_id into l_app from xxfnd_applications where application_code = 'COMMON';

        -- release 78: the six COMMON modules (feature group = lookup XXFND_MODULE, script 22)
        feature('APPLICATIONS',     'Applications',                  'PLATFORM', 110, 'VIEW,CREATE,MANAGE', 160,
                'fa-cubes',      'Registered applications, the common functions switched on for each, their setup.');
        feature('APP_SETTINGS',     'Application Settings',          'PLATFORM', 120, 'VIEW,MANAGE', 10022,
                'fa-sliders',    'Application settings.');
        feature('OPTIONAL_FEATURES', 'Optional Features',            'PLATFORM', 130, 'VIEW,MANAGE', 10020,
                'fa-toggle-on',  'Optional features of each application, switched on or off.');
        feature('USERS_ACCESS',     'Users ' || c_amp || ' Access',     'SECURITY', 210, 'VIEW,CREATE,MANAGE', 103,
                'fa-users',      'Users, their roles and their data access.');
        feature('ROLES_PRIVILEGES', 'Roles ' || c_amp || ' Privileges', 'SECURITY', 220, 'VIEW,CREATE,MANAGE', 105,
                'fa-key',        'Roles, the privileges they grant and segregation of duties.');
        feature('DATA_SECURITY',    'Data Security',                 'SECURITY', 230, 'VIEW,CREATE,MANAGE', 180,
                'fa-lock',       'Data access rules: which rows each user and role can see.');
        feature('AUDIT_LOG',        'Audit Log',                     'SECURITY', 240, 'VIEW', 111,
                'fa-history',    'Who changed what and when.');
        feature('LOOKUPS',          'Lookups',                       'REFERENCE_DATA', 310, 'VIEW,CREATE,MANAGE', 101,
                'fa-list-ul',    'Lists of values used across the application.');
        feature('FLEXFIELDS',       'Flexfields',                    'REFERENCE_DATA', 320, 'VIEW,CREATE,MANAGE', 152,
                'fa-table',      'Descriptive flexfields and their value sets.');
        feature('ATTACHMENTS',      'Attachments',                   'DOCUMENTS_RECORDS', 410, 'VIEW,CREATE,MANAGE', 132,
                'fa-paperclip',  'Document categories, storage and where attachments appear.');
        feature('RETENTION',        'Retention',                     'DOCUMENTS_RECORDS', 420, 'VIEW,CREATE,MANAGE', 112,
                'fa-archive',    'How long records and documents are kept.');
        feature('WORKFLOW_SETUP',   'Workflow Setup',                'WORKFLOW', 510, 'VIEW,CREATE,MANAGE', 114,
                'fa-sitemap',    'Delegations, deadlines and escalation, process catalogue.');
        feature('APPROVAL_SETUP',   'Approval Setup',                'WORKFLOW', 520, 'VIEW,CREATE,MANAGE', 148,
                'fa-check-square-o', 'Approval rules: who approves which record, step by step.');
        feature('NOTIFICATIONS',    'Notifications',                 'WORKFLOW', 530, 'VIEW,CREATE,MANAGE', 109,
                'fa-envelope-o', 'E-mail and in-app notification templates.');
        feature('INTEGRATIONS',     'Integrations',                  'INTEGRATIONS', 610, 'VIEW,CREATE,MANAGE', 120,
                'fa-plug',       'Endpoints, purposes and the transmission log.');

        pages('APPLICATIONS',      '160=Applications|162=Setup Types|164=Subscriptions|161|163');   -- 73: Setup Types; 78: Subscriptions
        pages('APP_SETTINGS',      '10022|10023');
        pages('OPTIONAL_FEATURES', '10020|10021');
        pages('USERS_ACCESS',      '103|104');
        pages('ROLES_PRIVILEGES',  '105=Roles|182=Privileges|107=Segregation of Duties|106|108');
        pages('DATA_SECURITY',     '180|181');
        pages('AUDIT_LOG',         '111');
        pages('LOOKUPS',           '101|102');
        pages('FLEXFIELDS',        '152=Descriptive Flexfields|150=Value Sets|151|153');
        pages('ATTACHMENTS',       '132=Categories|136=Storage|130=Registration|134=Attachment Pages|131|133|135|137');
        pages('RETENTION',         '112|113');
        pages('WORKFLOW_SETUP',    '114=Delegations|145=Deadlines ' || c_amp || ' Escalation|147=Process Catalogue|115|146');
        pages('APPROVAL_SETUP',    '148|149');
        pages('NOTIFICATIONS',     '109|110');
        pages('INTEGRATIONS',      '120=Endpoints|122=Purposes|124=Transmission Log|121|123|125');

        -- release 79: the Super Administrator is the business administrator of every workflow and task of every
        -- application (XXFND_WORKFLOW_PKG.BUSINESS_ADMINS returns the holders of WORKFLOW_MONITOR.MANAGE); granted from
        -- the console only (nobody holds it after the install)
        feature('WORKFLOW_MONITOR', 'Workflow Monitor', 'WORKFLOW', 540, 'VIEW,MANAGE', null,
                'fa-heartbeat', 'Running workflows and tasks of every application: act on anyone''s behalf.');
        merge into xxfnd_roles t using (select 'SUPER_ADMIN' role_code from dual) s on (t.role_code = s.role_code)
         when not matched then insert (role_code, application_code, application_id, role_name, description)
                               values (s.role_code, 'COMMON', l_app, 'Super Administrator',
                                       'Business administrator of every workflow and task of every application: '
                                       || 'suspends, resumes, retries, reassigns and delegates on anyone''s behalf.');
        merge into xxfnd_role_privileges t
        using (select 'SUPER_ADMIN' rc, 'WORKFLOW_MONITOR.' || column_value pc from table(apex_t_varchar2('VIEW', 'MANAGE'))) s
           on (t.role_code = s.rc and t.privilege_code = s.pc)
         when not matched then insert (role_code, privilege_code) values (s.rc, s.pc);

        -- the Common Administrator holds every admin privilege
        merge into xxfnd_role_privileges t
        using (select p.privilege_code from xxfnd_privileges p
                 join xxfnd_features f on f.feature_code = p.feature_code
                where f.admin_flag = 'Y') s
           on (t.role_code = 'COMMON_ADMIN' and t.privilege_code = s.privilege_code)
         when not matched then insert (role_code, privilege_code) values ('COMMON_ADMIN', s.privilege_code);

        xxfnd_util_pkg.set_install_mode(false);
        commit;
    exception
        when others then
            xxfnd_util_pkg.set_install_mode(false);
            raise;
    end seed_admin;

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
        seed_admin;
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
--------------------------------------------------------------------------------
-- 20 COMMON application seed (release 49). Installed by the COMMON application only.
--   The COMMON application (code and alias COMMON) runs on the XXFUSION schema and holds what every
--   application shares: security, flexfield and attachment setup, workflow. Its own access:
--     role    COMMON_ADMIN  - administers the shared setup
--     feature COMMON_HOME   - the home page (page 1)
--   The developer installing the application (or the workspace administrators, when installed without
--   an APEX session) becomes the first COMMON_ADMIN.
-- Idempotent: rows are inserted once; administrators maintain them on the setup screens.
--------------------------------------------------------------------------------
-- release 54: the seed is XXFND_SHARE_PKG.SEED_COMMON (script 19c), so the move of an application's shared data
-- (import_schema) can re-apply it.
begin
    xxfnd_share_pkg.seed_common;
    commit;
end;
/
--------------------------------------------------------------------------------
-- 21 COMMON administration seed (release 61). Installed by the COMMON application only (XXFUSION), after 20.
--   The shared setup screens run in the COMMON application for every registered application (16i: scope):
--   1. The admin features and their privileges - the same codes the business applications use, so a privilege a
--      user already holds works on the COMMON screen too. Created only when missing (an application's own rows,
--      once moved here, are kept).
--   2. Which COMMON page belongs to which feature (XXFND_FEATURE_PAGES, app alias COMMON), with the tabs.
--   3. The Common Administrator (COMMON_ADMIN) holds every admin privilege.
-- Idempotent: rows are created once; administrators maintain them on the screens. The seed is
--   XXFND_SHARE_PKG.SEED_ADMIN (script 19c), so the move of an application's shared data re-applies it.
--------------------------------------------------------------------------------
begin
    xxfnd_share_pkg.seed_admin;
end;
/
--------------------------------------------------------------------------------
-- 99 Sharing with the applications - last (release 87, C11). COMMON only (XXFUSION). The LAST script of every COMMON
--   install and upgrade: whatever an earlier script created is granted to every registered application's schema
--   (XXFND_SHARE_PKG.GRANT_TO_APPLICATIONS), the onboarding entry to every schema of the workspace (GRANT_ONBOARDING),
--   and anything left invalid is compiled again. Later releases add their scripts before this one.
-- Idempotent: a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_share_pkg.grant_to_applications;
    xxfnd_share_pkg.grant_onboarding;
end;
/
