--------------------------------------------------------------------------------
-- 22 COMMON modules (release 78). COMMON only (XXFUSION), after 21c.
--   COMMON is organised into six modules; each admin feature belongs to one (XXFND_FEATURES.FEATURE_GROUP):
--     PLATFORM           Applications, Application Settings, Optional Features
--     SECURITY           Users & Access, Roles & Privileges, Data Security, Audit Log
--     REFERENCE_DATA     Lookups, Flexfields
--     DOCUMENTS_RECORDS  Attachments, Retention
--     WORKFLOW           Workflow Setup, Approval Setup, Notifications
--     INTEGRATIONS       Integrations
--   1. The modules are the system lookup XXFND_MODULE (meaning = name, tag = icon, description, sequence).
--   2. Approval Setup (pages 148, 149) and Optional Features (pages 10020, 10021) become features of their own, so
--      each has a menu entry; roles and applications that had the old feature get the same rights on the new one.
--   3. The old groups BASIC_SETUP, WORKFLOW_INTEGRATION and APPLICATION are no longer used (they were only a column
--      value; no row is deleted).
--   4. XXFND_MODULES_V: the modules the user may open, with their state (the navigation menu, Home and page 100).
-- Idempotent: MERGE on natural keys and guarded updates; a re-run changes nothing.
--------------------------------------------------------------------------------
declare
    c_amp constant varchar2(1) := chr(38);   -- no literal ampersand: script runners substitute it
    l_app number;

    procedure module(p_code in varchar2, p_name in varchar2, p_seq in number, p_icon in varchar2, p_desc in varchar2) is
    begin
        merge into xxfnd_lookup_values t
        using (select 'XXFND_MODULE' lookup_type, p_code lookup_code from dual) s
           on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
         when matched then update set t.meaning = p_name, t.display_sequence = p_seq, t.tag = p_icon, t.description = p_desc
                           where decode(t.meaning, p_name, 0, 1) + decode(t.display_sequence, p_seq, 0, 1)
                               + decode(t.tag, p_icon, 0, 1) + decode(t.description, p_desc, 0, 1) > 0
         when not matched then insert (lookup_type, lookup_code, meaning, display_sequence, tag, description)
                               values (s.lookup_type, s.lookup_code, p_name, p_seq, p_icon, p_desc);
    end module;

    -- move a feature to its module (and its menu position), only when it is elsewhere
    procedure place(p_feature in varchar2, p_module in varchar2, p_seq in number) is
    begin
        update xxfnd_features
           set feature_group = p_module, display_sequence = p_seq
         where feature_code = p_feature
           and (feature_group <> p_module or decode(display_sequence, p_seq, 0, 1) = 1);
    end place;

    -- a new feature split from P_FROM: its pages move, and whoever had P_FROM's rights gets the same ones
    procedure split(p_code in varchar2, p_name in varchar2, p_from in varchar2, p_actions in varchar2,
                    p_home in number, p_icon in varchar2, p_desc in varchar2, p_pages in varchar2) is
    begin
        merge into xxfnd_features t using (select p_code c from dual) s on (t.feature_code = s.c)
         when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag,
                                       application_id, home_page_id, icon_css, description)
                               values (p_code, p_name, 'PLATFORM', 0, 'Y', l_app, p_home, p_icon, p_desc);
        for a in (select column_value action from table(apex_string.split(p_actions, ','))) loop
            merge into xxfnd_privileges t using (select p_code || '.' || a.action pc from dual) s
               on (t.privilege_code = s.pc)
             when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                                   values (s.pc, p_code, a.action, p_name || ' - ' || initcap(a.action));
            merge into xxfnd_role_privileges t
            using (select rp.role_code from xxfnd_role_privileges rp where rp.privilege_code = p_from || '.' || a.action) s
               on (t.role_code = s.role_code and t.privilege_code = p_code || '.' || a.action)
             when not matched then insert (role_code, privilege_code) values (s.role_code, p_code || '.' || a.action);
        end loop;
        merge into xxfnd_application_functions t
        using (select af.application_code, af.managed_in_app_flag from xxfnd_application_functions af
                where af.feature_code = p_from) s
           on (t.application_code = s.application_code and t.feature_code = p_code)
         when not matched then insert (application_code, feature_code, managed_in_app_flag)
                               values (s.application_code, p_code, s.managed_in_app_flag);
        -- the pages are no longer tabs of the old feature: the new feature has one list page
        update xxfnd_feature_pages
           set feature_code = p_code, tab_label = null, tab_sequence = null
         where app_alias = 'COMMON'
           and page_id in (select to_number(column_value) from table(apex_string.split(p_pages, ',')))
           and (feature_code <> p_code or tab_label is not null);
    end split;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select application_id into l_app from xxfnd_applications where application_code = 'COMMON';

    merge into xxfnd_lookup_types t using (select 'XXFND_MODULE' lookup_type from dual) s
       on (t.lookup_type = s.lookup_type)
     when not matched then insert (lookup_type, meaning, customization_level, application_code, description)
                           values (s.lookup_type, 'COMMON modules', 'S', 'COMMON',
                                   'The six modules of the COMMON application (menu groups). Tag: icon.');
    module('PLATFORM',          'Platform',              10, 'fa-cubes',
           'Registered applications, their setup types, settings and optional features.');
    module('SECURITY',          'Security',              20, 'fa-shield',
           'Users, roles and privileges, data access rules and the audit log.');
    module('REFERENCE_DATA',    'Reference Data',        30, 'fa-list-ul',
           'Lookups and flexfields shared by every application.');
    module('DOCUMENTS_RECORDS', 'Documents and Records', 40, 'fa-folder-open',
           'Document categories, storage, attachment pages and retention.');
    module('WORKFLOW',          'Workflow',              50, 'fa-sitemap',
           'Workflow setup, approval rules and notifications.');
    module('INTEGRATIONS',      'Integrations',          60, 'fa-plug',
           'External systems: endpoints, purposes and the transmission log.');

    split('APPROVAL_SETUP', 'Approval Setup', 'WORKFLOW_SETUP', 'VIEW,CREATE,MANAGE', 148, 'fa-check-square-o',
          'Approval rules: who approves which record, step by step.', '148,149');
    split('OPTIONAL_FEATURES', 'Optional Features', 'APP_SETTINGS', 'VIEW,MANAGE', 10020, 'fa-toggle-on',
          'Optional features of each application, switched on or off.', '10020,10021');
    update xxfnd_feature_pages set tab_label = null, tab_sequence = null
     where app_alias = 'COMMON' and page_id = 10022 and tab_label is not null;
    -- Subscriptions (page 164): a tab of Applications - which application subscribes to which COMMON master
    merge into xxfnd_feature_pages t using (select 'COMMON' app_alias, 164 page_id from dual) s
       on (t.app_alias = s.app_alias and t.page_id = s.page_id)
     when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                           values ('COMMON', 164, 'APPLICATIONS', 'Subscriptions', 30);

    place('APPLICATIONS',      'PLATFORM',          110);
    place('APP_SETTINGS',      'PLATFORM',          120);
    place('OPTIONAL_FEATURES', 'PLATFORM',          130);
    place('USERS_ACCESS',      'SECURITY',          210);
    place('ROLES_PRIVILEGES',  'SECURITY',          220);
    place('DATA_SECURITY',     'SECURITY',          230);
    place('AUDIT_LOG',         'SECURITY',          240);
    place('LOOKUPS',           'REFERENCE_DATA',    310);
    place('FLEXFIELDS',        'REFERENCE_DATA',    320);
    place('ATTACHMENTS',       'DOCUMENTS_RECORDS', 410);
    place('RETENTION',         'DOCUMENTS_RECORDS', 420);
    place('WORKFLOW_SETUP',    'WORKFLOW',          510);
    place('APPROVAL_SETUP',    'WORKFLOW',          520);
    place('NOTIFICATIONS',     'WORKFLOW',          530);
    place('INTEGRATIONS',      'INTEGRATIONS',      610);
    update xxfnd_features set feature_name = 'Flexfields'
     where feature_code = 'FLEXFIELDS' and feature_name <> 'Flexfields';
    -- optional features are a component of their own now
    update xxfnd_features set description = 'Application settings.'
     where feature_code = 'APP_SETTINGS' and description = 'Application settings and optional features.';

    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- The modules the current user may open (one of its features is on the admin menu for them), with a short state
-- that shows a problem without opening the screens. Used by the navigation menu, Home and page 100.
create or replace view xxfnd_modules_v as
select m.lookup_code                       as module_code,
       m.meaning                           as module_name,
       m.description,
       nvl(m.tag, 'fa-folder')             as icon_css,
       m.display_sequence,
       case m.lookup_code
           when 'PLATFORM' then
               (select count(*) || ' disabled application(s)'
                  from xxfnd_applications where enabled_flag = 'N' having count(*) > 0)
           when 'SECURITY' then
               (select count(*) || ' user(s) without a role'
                  from xxfnd_employees e
                 where e.enabled_flag = 'Y'
                   and not exists (select 1 from xxfnd_user_roles r
                                    where r.employee_id = e.employee_id and r.enabled_flag = 'Y'
                                      and trunc(sysdate) between r.start_date_active and nvl(r.end_date_active, trunc(sysdate)))
                having count(*) > 0)
           when 'DOCUMENTS_RECORDS' then
               'Retention not active yet'
           when 'WORKFLOW' then
               ltrim((select case when max(decode(application_code, 'COMMON', email_enabled_flag)) = 'N'
                                  then 'E-mail off for the workspace.' end
                        from xxfnd_applications)
                     || (select ' ' || count(*) || ' workflow(s) switched off'
                           from xxfnd_workflow_processes where workflow_enabled_flag = 'N' having count(*) > 0))
           when 'INTEGRATIONS' then
               (select count(*) || ' inactive endpoint(s)'
                  from xxfnd_integration_endpoints where status_code = 'INACTIVE' having count(*) > 0)
       end                                 as module_state
  from xxfnd_lookup_values m
 where m.lookup_type  = 'XXFND_MODULE'
   and m.enabled_flag = 'Y'
   and exists (select 1 from xxfnd_admin_menu_v a
                join xxfnd_feature_pages fp on fp.feature_code = a.feature_code and fp.app_alias = 'COMMON'
               where a.feature_group = m.lookup_code);

comment on table xxfnd_modules_v is 'COMMON modules (lookup XXFND_MODULE) the current user may open, with their state.';
