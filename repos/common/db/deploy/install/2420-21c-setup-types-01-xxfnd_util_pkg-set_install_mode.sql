--------------------------------------------------------------------------------
-- 21c Setup types (release 73). COMMON only (XXFUSION), after 21b.
--   Two levels, like profile options: the instance (COMMON: application empty, "All applications (instance)") and
--   an application. IT decides per setup type (XXFND_SETUP_TYPES, COMMON page 162/163):
--   - its allowed level: I = instance only, A = application only, B = instance or application;
--   - its allowed applications (application level): every registered application, or the ones listed in
--     XXFND_SETUP_TYPE_APPS.
--   The COMMON setup forms offer only what the type allows (LOV APPLICATIONS); a trigger (<table>_LV) checks the
--   application of every new or changed row on the screens. COMMON itself is the instance, not an application.
--   Also the tables and columns the setup forms list (XXFND_SETUP_TABLES_V / XXFND_SETUP_COLUMNS_V).
--   Release 80: tables and package in 09d (XXFND_APPLICATION_PKG); this script keeps the seed, the triggers and views.
-- Idempotent (release 69 rule: CREATE_TABLE only when missing; seed rows created once, IT maintains them).
--------------------------------------------------------------------------------
-- release 80: the tables XXFND_SETUP_TYPES / XXFND_SETUP_TYPE_APPS and the package are in 09d (XXFND_APPLICATION_PKG)

-- the setup types (created once; IT changes level and applications on page 163)
declare
    l_first boolean;
    l_n     pls_integer;
    procedure st(p_code in varchar2, p_name in varchar2, p_feature in varchar2, p_table in varchar2,
                 p_list in number, p_form in number, p_level in varchar2, p_seq in number, p_desc in varchar2) is
    begin
        merge into xxfnd_setup_types t using (select upper(p_code) c from dual) s on (t.setup_type_code = s.c)
         when not matched then insert (setup_type_code, setup_type_name, feature_code, table_name, list_page_id,
                                       form_page_id, allowed_level, all_applications_flag, display_sequence, description)
                               values (s.c, p_name, p_feature, p_table, p_list, p_form, p_level, 'Y', p_seq, p_desc);
    end st;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select count(*) into l_n from xxfnd_setup_types;
    l_first := l_n = 0;
    st('LOOKUPS',                'Lookups',                  'LOOKUPS',          'XXFND_LOOKUP_TYPES',           101,   102,   'B',  10, 'Lookup types and their values.');
    st('VALUE_SETS',             'Value Sets',               'FLEXFIELDS',       'XXFND_VALUE_SETS',             150,   151,   'I',  20, 'Lists of values the flexfields use.');
    st('FLEXFIELDS',             'Descriptive Flexfields',   'FLEXFIELDS',       'XXFND_DF_FLEXFIELDS',          152,   153,   'A',  30, 'Extra fields on a screen of an application.');
    st('DOCUMENT_CATEGORIES',    'Document Categories',      'ATTACHMENTS',      'XXFND_DOCUMENT_CATEGORIES',    132,   133,   'B',  40, 'Kinds of attached documents.');
    st('DOCUMENT_STORAGE',       'Document Storage',         'ATTACHMENTS',      'XXFND_STORAGE_CONFIG',         136,   137,   'B',  50, 'Where attached documents are kept: per application and category (release 86).');
    st('DOCUMENT_ENTITIES',      'Document Entities',        'ATTACHMENTS',      'XXFND_DOCUMENT_ENTITIES',      130,   131,   'B',  60, 'Records documents can be attached to.');
    st('ATTACHMENT_PAGES',       'Attachment Pages',         'ATTACHMENTS',      'XXFND_ATTACHMENT_FUNCTIONS',   134,   135,   'A',  70, 'Screens of an application that show attachments.');
    st('NOTIFICATION_TEMPLATES', 'Notification Templates',   'NOTIFICATIONS',    'XXFND_NOTIFICATION_TEMPLATES', 109,   110,   'B',  80, 'Texts of notifications and e-mails.');
    st('RETENTION_POLICIES',     'Retention Policies',       'RETENTION',        'XXFND_RETENTION_POLICIES',     112,   113,   'I',  90, 'How long records are kept.');
    st('SERVERS',                'Servers',                  'INTEGRATIONS',     'XXFND_SERVERS',                120,   121,   'I', 100, 'Workspace servers (APEX Remote Servers and Web Credentials) for storage and integrations.');
    st('INTEGRATION_PURPOSES',   'Integration Purposes',     'INTEGRATIONS',     'XXFND_INTEGRATION_PURPOSES',   122,   123,   'B', 110, 'What a server is used for.');
    st('USERS',                  'Users ' || chr(38) || ' Access', 'USERS_ACCESS', null,                          103,   104,   'I', 120, 'Employees, users and their roles.');
    st('ROLES',                  'Roles',                    'ROLES_PRIVILEGES', 'XXFND_ROLES',                  105,   106,   'A', 130, 'Roles and their privileges.');
    st('SEGREGATION_OF_DUTIES',  'Segregation of Duties',    'ROLES_PRIVILEGES', null,                           107,   108,   'A', 140, 'Roles one user may not hold together.');
    st('DATA_SECURITY',          'Data Objects',             'DATA_SECURITY',    null,                           180,   181,   'A', 150, 'Release 96: secured tables and the roles that reach their records.');
    st('DELEGATIONS',            'Delegations',              'WORKFLOW_SETUP',   null,                           114,   115,   'I', 160, 'Tasks handed to another user while away.');
    st('TASK_DEADLINES',         'Deadlines ' || chr(38) || ' Escalation', 'WORKFLOW_SETUP', null,               145,   146,   'A', 170, 'Due dates and escalation of approval tasks.');
    st('WORKFLOW_PROCESSES',     'Workflow Processes',       'WORKFLOW_SETUP',   null,                           147,   null,  'A', 180, 'Approval processes, their workflow and e-mail switches.');
    st('AUDIT_LOG',              'Audit Log',                'AUDIT_LOG',        null,                           111,   null,  'I', 190, 'Changes made to the setup and data.');
    st('FEATURE_CONFIGURATION',  'Optional Features',        'APP_SETTINGS',     null,                           10020, 10021, 'A', 200, 'Optional features of an application.');
    st('APPLICATION_SETTINGS',   'Application Settings',     'APP_SETTINGS',     null,                           10022, 10023, 'A', 210, 'Settings of an application.');

    -- COMMON is the instance: its rows become instance rows (roles keep theirs: a role always has an application)
    for t in (select s.table_name from xxfnd_setup_types s
               where s.table_name is not null and s.table_name <> 'XXFND_ROLES'
                 and exists (select 1 from user_tab_columns c
                              where c.table_name = s.table_name and c.column_name = 'APPLICATION_CODE')) loop
        execute immediate 'update ' || t.table_name || ' set application_code = null where application_code = ''COMMON''';
    end loop;
    if l_first then
        -- first install: instance-only types keep their rows for every application
        for t in (select s.table_name from xxfnd_setup_types s
                   where s.allowed_level = 'I' and s.table_name is not null
                     and exists (select 1 from user_tab_columns c
                                  where c.table_name = s.table_name and c.column_name = 'APPLICATION_CODE')) loop
            execute immediate 'update ' || t.table_name || ' set application_code = null where application_code is not null';
        end loop;
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

begin
    xxfnd_application_pkg.create_triggers;
end;
/

-- the Setup Types pages belong to the Applications feature (tabs Applications / Setup Types)
begin
    xxfnd_util_pkg.set_install_mode(true);
    update xxfnd_feature_pages set tab_label = 'Applications', tab_sequence = 10
     where app_alias = 'COMMON' and page_id = 160 and feature_code = 'APPLICATIONS' and tab_label is null;
    merge into xxfnd_feature_pages d
    using (select 162 page_id, 'Setup Types' tab_label, 20 tab_sequence from dual union all
           select 163, null, null from dual) s
       on (d.app_alias = 'COMMON' and d.page_id = s.page_id)
     when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                           values ('COMMON', s.page_id, 'APPLICATIONS', s.tab_label, s.tab_sequence);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
