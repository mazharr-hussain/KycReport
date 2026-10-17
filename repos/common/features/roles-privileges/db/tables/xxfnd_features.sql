--------------------------------------------------------------------------------
-- C02 Security framework (release R10)
-- Features -> privileges (VIEW / CREATE / MANAGE) -> roles, maintained in the
-- application. Pages map to features, so rebuilding a screen only changes the
-- mapping. Row-level data security: typed rules enforced by one generic VPD
-- policy. Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create table if not exists xxfnd_features (
    feature_code           varchar2(30)   not null,
    feature_name           varchar2(240)  not null,
    feature_group          varchar2(30)   not null,
    display_sequence       number         default 100 not null,
    admin_flag             varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_features_pk primary key (feature_code),
    constraint xxfnd_features_ck1 check (admin_flag in ('Y','N')),
    constraint xxfnd_features_ck2 check (enabled_flag in ('Y','N'))
);
comment on table xxfnd_features is 'Application features (one menu entry each). Privileges are granted per feature and action.';

-- release 46: a feature belongs to one application (shared access module)
declare
begin
    xxfnd_ddl_pkg.add_column('XXFND_FEATURES', 'APPLICATION_ID', 'number');
    begin
        execute immediate 'alter table xxfnd_features add constraint xxfnd_features_fk1 foreign key (application_id) references xxfnd_applications (application_id)';
    exception when others then if sqlcode not in (-2275, -2264) then raise; end if;
    end;
end;
/
comment on column xxfnd_features.application_id is 'The application (XXFND_APPLICATIONS) the feature belongs to; its privileges and page mappings follow it.';

begin
    for t in (select table_name from user_tables
               where table_name in ('XXFND_FEATURES','XXFND_PRIVILEGES','XXFND_FEATURE_PAGES',
                                    'XXFND_ROLE_PRIVILEGES','XXFND_DATA_SECURITY_RULES',
                                    'XXFND_DATA_RULE_ASSIGNMENTS')) loop
        xxfnd_util_pkg.create_who_trigger(t.table_name);
    end loop;
    -- Security configuration is audited like every other setup table.
    xxfnd_audit_pkg.create_audit_trigger('XXFND_ROLE_PRIVILEGES');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_DATA_SECURITY_RULES');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_DATA_RULE_ASSIGNMENTS');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_FEATURE_PAGES');
end;
/
--------------------------------------------------------------------------------
-- 09c Shared objects formerly created by KYC scripts (release 54). COMMON only.
--   The shared XXFND_ objects live only in XXFUSION, so their DDL runs there: the admin console columns,
--   index and view (from 18c) and the maker-checker trigger of the integration purposes (from 16).
-- Idempotent.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_FEATURES',      'HOME_PAGE_ID', 'number');
    xxfnd_ddl_pkg.add_column('XXFND_FEATURES',      'ICON_CSS',     'varchar2(60)');
    xxfnd_ddl_pkg.add_column('XXFND_FEATURE_PAGES', 'TAB_LABEL',    'varchar2(60)');
    xxfnd_ddl_pkg.add_column('XXFND_FEATURE_PAGES', 'TAB_SEQUENCE', 'number');
    -- the audit trigger lists the columns: regenerate it for the new ones
    xxfnd_audit_pkg.create_audit_trigger('XXFND_FEATURE_PAGES');
end;
/

comment on column xxfnd_features.home_page_id is 'Page opened by the feature''s menu entry.';
--------------------------------------------------------------------------------
-- 23 COMMON Security module (release 79). COMMON only (XXFUSION), after 22.
--   Users & Access, Roles & Privileges and Data Security work as one module: a data access rule is assigned to
--   users and roles (XXFND_DATA_RULE_ASSIGNMENTS, 09b), the three screens share one Assign dialog (page 183).
--   This script brings the descriptions an existing installation already has in line with that; a fresh install
--   gets them from the admin seed (19c).
-- Idempotent: guarded updates; a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_util_pkg.set_install_mode(true);
    update xxfnd_features set description = 'Users, their roles and their data access.'
     where feature_code = 'USERS_ACCESS' and description = 'Employees and the roles they hold.';
    update xxfnd_features set description = 'Data access rules: which rows each user and role can see.'
     where feature_code = 'DATA_SECURITY' and description = 'Which rows each role can see.';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
--------------------------------------------------------------------------------
-- 27 Shared screens (release 85). COMMON only (XXFUSION), after 26.
--   The screens every application uses from COMMON, with their privileges (every page has View and Manage or
--   Create; data security on the rows):
--   - Documents (47 Attachments of a record, 48 Document: add, view, replace): any application opens them for its
--     record; who may add / replace / remove comes from the attachment page registration (XXFND_ATTACH_PKG
--     BLOCK_PERMISSION) and the record must be visible to the user (XXFND_ATTACH_PKG.RECORD_VISIBLE).
--   - Platform Activity (170): page views, top users, errors and page performance of every registered application.
--   - Feedback (171 list, 172 follow-up: Usage and Feedback) and Give Feedback (173, every role) for every
--     application.
--   COMMON's Communications page (45) is registered for the documents of its e-mails.
--   Features and pages are added when missing; a privilege is given to the roles once, when its feature is created.
-- Idempotent: merges when missing; a re-run changes nothing.
--------------------------------------------------------------------------------
declare
    l_app number;
    procedure feature(p_code in varchar2, p_name in varchar2, p_group in varchar2, p_seq in number, p_admin in varchar2,
                      p_home in number, p_icon in varchar2, p_desc in varchar2, p_actions in varchar2, p_roles in varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from xxfnd_features where feature_code = p_code;
        if l_n = 0 then
            insert into xxfnd_features (feature_code, feature_name, feature_group, display_sequence, admin_flag,
                                        application_id, home_page_id, icon_css, description)
            values (p_code, p_name, p_group, p_seq, p_admin, l_app, p_home, p_icon, p_desc);
        end if;
        merge into xxfnd_privileges t
        using (select p_code || '.' || column_value pc, column_value act from table(apex_string.split(p_actions, ','))) s
           on (t.privilege_code = s.pc)
         when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                               values (s.pc, p_code, s.act, p_name || ' - ' || initcap(s.act));
        if l_n = 0 then
            -- the privileges go to the roles once, when the feature is created: what the console changes later is kept
            insert into xxfnd_role_privileges (role_code, privilege_code)
            select r.role_code, p_code || '.' || a.column_value
              from xxfnd_roles r cross join table(apex_string.split(p_actions, ',')) a
             where (p_roles = 'ALL' or r.role_code in (select column_value from table(apex_string.split(p_roles, ','))))
               and not exists (select 1 from xxfnd_role_privileges x
                                where x.role_code = r.role_code and x.privilege_code = p_code || '.' || a.column_value);
        end if;
    end feature;
    procedure page(p_feature in varchar2, p_page in number) is
    begin
        merge into xxfnd_feature_pages d
        using (select 'COMMON' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when not matched then insert (app_alias, page_id, feature_code) values ('COMMON', p_page, p_feature);
    end page;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select application_id into l_app from xxfnd_applications where application_code = 'COMMON';
    feature('DOCUMENTS', 'Documents', 'BUSINESS', 40, 'N', 47, 'fa-paperclip',
            'The documents of a record of any application: add, view, replace (the application''s attachment page registration says who may change them).',
            'VIEW,CREATE,MANAGE', 'ALL');
    feature('PLATFORM_ACTIVITY', 'Platform Activity', 'PLATFORM', 60, 'Y', 170, 'fa-line-chart',
            'Page views, top users, errors and page performance of every registered application (APEX activity log).',
            'VIEW,MANAGE', 'COMMON_ADMIN');
    feature('USAGE_FEEDBACK', 'Usage and Feedback', 'PLATFORM', 65, 'Y', 171, 'fa-comments-o',
            'The feedback people gave on every registered application, and its follow-up.',
            'VIEW,MANAGE', 'COMMON_ADMIN');
    feature('GIVE_FEEDBACK', 'Give Feedback', 'BUSINESS', 50, 'N', 173, 'fa-comment-o',
            'Everyone gives feedback on the page they are on, in any application.',
            'VIEW,CREATE', 'ALL');
    -- COMMON's own Communications page (45) keeps the documents of an e-mail: its attachment page registration (the
    -- e-mails region; add and replace, no remove), added when missing
    merge into xxfnd_attachment_functions t using (select 'COMMON_COMMUNICATIONS' function_code from dual) s
       on (t.function_code = s.function_code)
     when not matched then insert (function_code, application_code, function_name, apex_app_alias, apex_page_id, enabled_flag)
                           values ('COMMON_COMMUNICATIONS', 'COMMON', 'Communications - e-mails of a record', 'COMMON', 45, 'Y');
    merge into xxfnd_attachment_blocks t
    using (select 'COMMON_COMMUNICATIONS' function_code, 'EMAILS' block_code from dual) s
       on (t.function_code = s.function_code and t.block_code = s.block_code)
     when not matched then insert (function_code, block_code, region_static_id, block_name, display_sequence)
                           values ('COMMON_COMMUNICATIONS', 'EMAILS', 'history', 'E-mails', 10);
    merge into xxfnd_attachment_blk_entities t
    using (select 'COMMON_COMMUNICATIONS' function_code, 'EMAILS' block_code, 'XXFND_COMMUNICATIONS' entity_name from dual) s
       on (t.function_code = s.function_code and t.block_code = s.block_code and t.entity_name = s.entity_name)
     when not matched then insert (function_code, block_code, entity_name, pk1_page_item, insert_allowed_flag,
                                   update_allowed_flag, delete_allowed_flag, display_sequence)
                           values ('COMMON_COMMUNICATIONS', 'EMAILS', 'XXFND_COMMUNICATIONS', 'COMMUNICATION_ID', 'Y', 'Y', 'N', 10);
    page('DOCUMENTS', 47);
    page('DOCUMENTS', 48);
    page('PLATFORM_ACTIVITY', 170);
    page('USAGE_FEEDBACK', 171);
    page('USAGE_FEEDBACK', 172);
    page('GIVE_FEEDBACK', 173);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
