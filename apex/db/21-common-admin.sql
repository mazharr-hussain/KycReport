--------------------------------------------------------------------------------
-- 21 COMMON administration seed (release 61). Installed by the COMMON application only (XXFUSION), after 20.
--   The shared setup screens run in the COMMON application for every registered application (16i: scope):
--   1. The admin features and their privileges - the same codes the business applications use, so a privilege a
--      user already holds works on the COMMON screen too. Created only when missing (an application's own rows,
--      once moved here, are kept).
--   2. Which COMMON page belongs to which feature (XXFND_FEATURE_PAGES, app alias COMMON), with the tabs.
--   3. The Common Administrator (COMMON_ADMIN) holds every admin privilege.
-- Idempotent: rows are created once; administrators maintain them on the screens.
--------------------------------------------------------------------------------
declare
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

    feature('LOOKUPS',          'Lookups',                       'BASIC_SETUP', 110, 'VIEW,CREATE,MANAGE', 101,
            'fa-list-ul',    'Lists of values used across the application.');
    feature('FLEXFIELDS',       'Flexfields (DFF)',              'BASIC_SETUP', 120, 'VIEW,CREATE,MANAGE', 152,
            'fa-table',      'Descriptive flexfields and their value sets.');
    feature('ATTACHMENTS',      'Attachments',                   'BASIC_SETUP', 140, 'VIEW,CREATE,MANAGE', 132,
            'fa-paperclip',  'Document categories, storage and where attachments appear.');
    feature('NOTIFICATIONS',    'Notifications',                 'BASIC_SETUP', 150, 'VIEW,CREATE,MANAGE', 109,
            'fa-envelope-o', 'E-mail and in-app notification templates.');
    feature('RETENTION',        'Retention',                     'BASIC_SETUP', 160, 'VIEW,CREATE,MANAGE', 112,
            'fa-archive',    'How long records and documents are kept.');
    feature('WORKFLOW_SETUP',   'Workflow Setup',                'WORKFLOW_INTEGRATION', 210, 'VIEW,CREATE,MANAGE', 114,
            'fa-sitemap',    'Delegations, deadlines and escalation, process catalogue.');
    feature('INTEGRATIONS',     'Integrations',                  'WORKFLOW_INTEGRATION', 240, 'VIEW,CREATE,MANAGE', 120,
            'fa-plug',       'Endpoints, purposes and the transmission log.');
    feature('USERS_ACCESS',     'Users ' || c_amp || ' Access',     'SECURITY', 310, 'VIEW,CREATE,MANAGE', 103,
            'fa-users',      'Employees and the roles they hold.');
    feature('ROLES_PRIVILEGES', 'Roles ' || c_amp || ' Privileges', 'SECURITY', 320, 'VIEW,CREATE,MANAGE', 105,
            'fa-key',        'Roles, the privileges they grant and segregation of duties.');
    feature('DATA_SECURITY',    'Data Security',                 'SECURITY', 330, 'VIEW,CREATE,MANAGE', 180,
            'fa-lock',       'Which rows each role can see.');
    feature('AUDIT_LOG',        'Audit Log',                     'SECURITY', 340, 'VIEW', 111,
            'fa-history',    'Who changed what and when.');
    feature('APP_SETTINGS',     'Application Settings',          'APPLICATION', 410, 'VIEW,MANAGE', 10022,
            'fa-sliders',    'Application settings and optional features.');

    pages('LOOKUPS',          '101|102');
    pages('FLEXFIELDS',       '152=Descriptive Flexfields|150=Value Sets|151|153');
    pages('ATTACHMENTS',      '132=Categories|136=Storage|130=Registration|134=Attachment Pages|131|133|135|137');
    pages('NOTIFICATIONS',    '109|110');
    pages('RETENTION',        '112|113');
    pages('WORKFLOW_SETUP',   '114=Delegations|145=Deadlines ' || c_amp || ' Escalation|147=Process Catalogue|115|146');
    pages('INTEGRATIONS',     '120=Endpoints|122=Purposes|124=Transmission Log|121|123|125');
    pages('USERS_ACCESS',     '103|104');
    pages('ROLES_PRIVILEGES', '105=Roles|182=Privileges|107=Segregation of Duties|106|108');
    pages('DATA_SECURITY',    '180|181');
    pages('AUDIT_LOG',        '111');
    pages('APP_SETTINGS',     '10022=Settings|10020=Optional Features|10021|10023');

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
end;
/
