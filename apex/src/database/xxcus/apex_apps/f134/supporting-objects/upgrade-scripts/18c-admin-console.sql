--------------------------------------------------------------------------------
-- C03 Admin console (release R11)
-- One menu entry per feature: each feature has a landing page and an icon; the
-- list pages of a feature are shown as tabs (XXFND_FEATURE_PAGES.TAB_LABEL).
-- The Administration console and the tabs are dynamic lists over these tables.
-- Idempotent: columns are added once; seed values only fill empty columns.
--------------------------------------------------------------------------------
-- release 54: the columns, index and view of the admin console are shared objects: script 09c (COMMON).

declare
    procedure feature(p_code in varchar2, p_home in number, p_icon in varchar2, p_description in varchar2) is
    begin
        update xxfnd_features
           set home_page_id = nvl(home_page_id, p_home),
               icon_css     = nvl(icon_css, p_icon),
               description  = nvl(description, p_description)
         where feature_code = p_code;
    end feature;

    -- p_tabs: page_id=Label pairs separated by '|', in tab order
    procedure tabs(p_feature in varchar2, p_tabs in varchar2) is
        l_seq pls_integer := 0;
        l_page number;
    begin
        for t in (select column_value pair from table(apex_string.split(p_tabs, '|'))) loop
            l_seq  := l_seq + 10;
            l_page := to_number(substr(t.pair, 1, instr(t.pair, '=') - 1));
            merge into xxfnd_feature_pages d
            using (select 'KYC' app_alias, l_page page_id from dual) s
               on (d.app_alias = s.app_alias and d.page_id = s.page_id)
             when matched then update
                  set d.tab_label    = nvl(d.tab_label, substr(t.pair, instr(t.pair, '=') + 1)),
                      d.tab_sequence = nvl(d.tab_sequence, l_seq)
             when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                  values ('KYC', l_page, p_feature, substr(t.pair, instr(t.pair, '=') + 1), l_seq);
        end loop;
    end tabs;

    procedure page(p_feature in varchar2, p_page in number) is
    begin
        merge into xxfnd_feature_pages d
        using (select 'KYC' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when not matched then insert (app_alias, page_id, feature_code) values ('KYC', p_page, p_feature);
    end page;
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- Basic Setup
    feature('LOOKUPS',          101,   'fa-list-ul',          'Lists of values used across the application.');
    feature('FLEXFIELDS',       152,   'fa-table',            'Descriptive flexfields and their value sets.');
    feature('KYC_RULES',        160,   'fa-question-circle-o','Questionnaires, questions, scoring and conclusion templates.');
    feature('ATTACHMENTS',      132,   'fa-paperclip',        'Document categories, mandatory documents, storage and where attachments appear.');
    feature('NOTIFICATIONS',    109,   'fa-envelope-o',       'E-mail and in-app notification templates.');
    feature('RETENTION',        112,   'fa-archive',          'How long records and documents are kept.');
    -- Workflow and Integration
    feature('WORKFLOW_SETUP',   165,   'fa-sitemap',          'SAR gate, delegations, deadlines and escalation, process catalogue (approvers: COMMON Approval Setup).');
    feature('WORKFLOW_MONITOR', 41,    'fa-heartbeat',        'Running workflow items: suspend, resume, move or cancel.');
    feature('INTEGRATIONS',     120,   'fa-plug',             'Endpoints, purposes and the transmission log.');
    -- Security
    feature('USERS_ACCESS',     103,   'fa-users',            'Employees and the roles they hold.');
    feature('ROLES_PRIVILEGES', 105,   'fa-key',              'Roles, the privileges they grant and segregation of duties.');
    feature('DATA_SECURITY',    180,   'fa-lock',             'Which rows each role can see.');
    feature('AUDIT_LOG',        111,   'fa-history',          'Who changed what and when.');
    -- Application
    feature('APP_SETTINGS',     10022, 'fa-sliders',          'Application settings and optional features.');
    feature('USAGE_FEEDBACK',   10030, 'fa-bar-chart',        'Activity reports and user feedback.');

    tabs('FLEXFIELDS',       '152=Descriptive Flexfields|150=Value Sets');
    tabs('KYC_RULES',        '160=Questionnaires|163=Conclusion Templates');
    tabs('ATTACHMENTS',      '132=Categories|138=Mandatory Documents|136=Storage|130=Registration|134=Attachment Pages');
    tabs('WORKFLOW_SETUP',   '165=SAR Gate|114=Delegations');   -- release 74: approvers in COMMON Approval Setup
    tabs('INTEGRATIONS',     '120=Endpoints|122=Purposes|124=Transmission Log');
    tabs('ROLES_PRIVILEGES', '105=Roles|182=Privileges|107=Segregation of Duties');
    tabs('APP_SETTINGS',     '10022=Settings|10020=Optional Features');
    tabs('USAGE_FEEDBACK',   '10030=Activity|10051=Feedback');
    page('DATA_SECURITY', 180);
    page('DATA_SECURITY', 181);
    page('APP_SETTINGS',  10023);
    xxfnd_util_pkg.set_install_mode(false);
    xxfnd_ddl_pkg.mark_release('R11', 'Release 11: admin console (feature landing pages, tabs, security screens)');
    commit;
end;
/

-- release 46: the features seeded here belong to the KYC application
update xxfnd_features set application_id = (select application_id from xxfnd_applications where application_code = 'KYC')
 where application_id is null;
commit;
