
begin
    if xxfnd_ddl_pkg.create_table('XXFND_LOOKUP_VALUES', q'~create table xxfnd_lookup_values (
    lookup_type            varchar2(30)   not null,
    lookup_code            varchar2(30)   not null,
    meaning                varchar2(200)  not null,
    description            varchar2(500),
    tag                    varchar2(150),
    parent_lookup_type     varchar2(30),
    parent_lookup_code     varchar2(30),
    display_sequence       number,
    enabled_flag           varchar2(1)    default 'Y' not null,
    start_date_active      date           default trunc(sysdate) not null,
    end_date_active        date,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_lookup_values_pk primary key (lookup_type, lookup_code),
    constraint xxfnd_lookup_values_fk1 foreign key (lookup_type) references xxfnd_lookup_types (lookup_type),
    constraint xxfnd_lookup_values_fk2 foreign key (parent_lookup_type, parent_lookup_code)
        references xxfnd_lookup_values (lookup_type, lookup_code),
    constraint xxfnd_lookup_values_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_lookup_values_ck2 check (end_date_active is null or end_date_active >= start_date_active)
)~') then
        xxfnd_ddl_pkg.run(q'~create index xxfnd_lookup_values_n1 on xxfnd_lookup_values (parent_lookup_type, parent_lookup_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table  xxfnd_lookup_values is 'Lookup values (FND_LOOKUP_VALUES). Parent columns support dependent (cascading) values.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_lookup_values.tag is 'One extra attribute for a value, e.g. a jurisdiction''s UBO threshold. Needs more than one? Use a dedicated table.'~');
    end if;
end;
/
--------------------------------------------------------------------------------
-- 15e Communications (release 74, R27). COMMON only (XXFUSION); every application uses it.
--   XXFND_COMMUNICATIONS: every e-mail with an outside person that belongs to a record (a case, a request for
--   information ...): sent from the application, or a reply received and recorded. Sent now through APEX mail;
--   received e-mails are typed (or pasted) by a person now. The Outlook provision: an Outlook (Microsoft Graph)
--   integration later fills the same table through RECORD_RECEIVED (SOURCE OUTLOOK) and matches replies by
--   CONVERSATION_ID / EXTERNAL_MESSAGE_ID; nothing else changes. Server OUTLOOK_GRAPH (release 86; disabled) and
--   purpose EMAIL_SYNC (manual) are registered for it.
--   Attachments: entity XXFND_COMMUNICATIONS (common attachments), registered by each application that uses it.
-- Release 82: the table is created in 15 and the package is XXFND_NOTIFY_PKG (15); this script keeps the seeds.
-- Idempotent (CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------


-- the Outlook provision (inactive until the integration is built), lookups and data security: COMMON administrators
-- see every row; each application adds its own rule (e.g. KYC's Compliance team)
declare
    procedure lv(p_type in varchar2, p_code in varchar2, p_meaning in varchar2, p_seq in number) is
    begin
        merge into xxfnd_lookup_values t using (select p_type lookup_type, p_code lookup_code from dual) s
           on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
         when not matched then insert (lookup_type, lookup_code, meaning, display_sequence)
                               values (p_type, p_code, p_meaning, p_seq);
    end lv;
begin
    xxfnd_util_pkg.set_install_mode(true);
    merge into xxfnd_lookup_types t using (select 'COMMUNICATION_STATUS' lookup_type from dual) s
       on (t.lookup_type = s.lookup_type)
     when not matched then insert (lookup_type, meaning) values ('COMMUNICATION_STATUS', 'Communication Statuses');
    lv('COMMUNICATION_STATUS', 'SENT', 'Sent', 10);
    lv('COMMUNICATION_STATUS', 'NOT_SENT', 'Recorded, not sent (e-mail switched off)', 20);
    lv('COMMUNICATION_STATUS', 'FAILED', 'Failed', 30);
    lv('COMMUNICATION_STATUS', 'RECEIVED', 'Received', 40);
    -- release 86: the Outlook server is a workspace server (XXFND_SERVERS; was the endpoint OUTLOOK_GRAPH)
    merge into xxfnd_servers t using (select 'OUTLOOK_GRAPH' server_code from dual) s
       on (t.server_code = s.server_code)
     when not matched then insert (server_code, server_name, server_type, base_url, credential_static_id, enabled_flag,
                                   description)
                           values ('OUTLOOK_GRAPH', 'Outlook (Microsoft Graph)', 'OUTLOOK', 'https://graph.microsoft.com/v1.0',
                                   'XXFND_GRAPH_CRED', 'N',
                                   'Planned: sends and receives the e-mails of the RFI and Notes screens '
                                   || '(XXFND_COMMUNICATIONS). Not built yet: e-mails are sent by APEX mail and replies recorded by hand.');
    merge into xxfnd_integration_purposes t using (select 'EMAIL_SYNC' purpose_code from dual) s
       on (t.purpose_code = s.purpose_code)
     when not matched then insert (purpose_code, application_code, purpose_name, capture_method, approval_status)
                           values ('EMAIL_SYNC', null, 'E-mail with outside parties (Outlook)', 'MANUAL', 'APPROVED');
    -- data security: the Common administrators' rule is seeded by XXFND_SHARE_PKG.SEED_COMMON (19c, run by 20, after the role); applications add theirs
    commit;
    xxfnd_util_pkg.set_install_mode(false);
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
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
           'External systems: servers, purposes and the transmission log.');

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
--------------------------------------------------------------------------------
-- 29 Workspace servers and document storage per application (release 86, part B). COMMON only (XXFUSION), after 28.
--   The tables, columns and views this release needs are created where their owner runs earlier (checked steps):
--   XXFND_SERVERS, XXFND_SERVERS_V and XXFND_INTEGRATION_PURPOSES.SERVER_CODE in 05b (integrations); the storage
--   columns, XXFND_DOCUMENTS.SERVER_CODE / STORAGE_CONTAINER and XXFND_APP_STORAGE_V in 14 (attachments).
--   This script:
--   1. Lookups SERVER_TYPE (the six server types) and STORAGE_TYPE (+ OCI Object Storage, Database).
--   2. Copies the retired XXFND_INTEGRATION_ENDPOINTS into XXFND_SERVERS (base URL, Web Credential, OAuth token URL)
--      where no server of that code exists; adds the servers COMMON ships as workspace components (FUSION, UCM_MAIN,
--      SHAREPOINT_MAIN) when missing.
--   3. Purposes: SERVER_CODE from the old endpoint; an API purpose needs a REST Data Source or a server (CK5, was CK4).
--   4. Converts the old storage rules (entity / category / endpoint, shared or per application) into the new form:
--      one row per application (category empty = the application default; application empty = COMMON) and per
--      category override; the server is the old endpoint. A shared rule becomes the rule of COMMON and of every
--      registered application that has none; of several old rules for the same application and category the generic
--      one (no entity), then the lowest priority, stays enabled - the others are disabled, not deleted (documents
--      stored by them keep their location). Documents record their server and library (STORAGE_CONTAINER).
--   5. Drops the retired endpoint objects: trigger XXFND_INT_ENDPOINTS_RO, the foreign keys to the table and the table
--      (XXFND_DDL_PKG.DROP_OBJECT records the DDL; the table goes to the recycle bin, not purged).
--   6. Setup types: Document Storage at instance or application level; Servers (table XXFND_SERVERS) replaces
--      Integration Endpoints.
-- Idempotent: every step acts only when needed; a re-run changes nothing.
--------------------------------------------------------------------------------

-- 1. lookups
declare
    procedure lv(p_type in varchar2, p_code in varchar2, p_meaning in varchar2, p_seq in number) is
    begin
        merge into xxfnd_lookup_values t using (select p_type lookup_type, p_code lookup_code from dual) s
           on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
         when not matched then insert (lookup_type, lookup_code, meaning, display_sequence)
                               values (p_type, p_code, p_meaning, p_seq);
    end lv;
begin
    xxfnd_util_pkg.set_install_mode(true);
    merge into xxfnd_lookup_types t using (select 'SERVER_TYPE' lookup_type from dual) s
       on (t.lookup_type = s.lookup_type)
     when not matched then insert (lookup_type, meaning, customization_level, description)
                           values ('SERVER_TYPE', 'Server Types', 'S',
                                   'Release 86: types of the workspace servers (XXFND_SERVERS). Storage: OBJECT_STORAGE, '
                                   || 'SHAREPOINT, UCM; integration: FUSION, REST, OUTLOOK.');
    lv('SERVER_TYPE', 'OBJECT_STORAGE', 'OCI Object Storage', 10);
    lv('SERVER_TYPE', 'SHAREPOINT', 'Microsoft SharePoint (Graph)', 20);
    lv('SERVER_TYPE', 'UCM', 'Oracle WebCenter Content (UCM)', 30);
    lv('SERVER_TYPE', 'FUSION', 'Oracle Fusion Cloud', 40);
    lv('SERVER_TYPE', 'REST', 'REST service', 50);
    lv('SERVER_TYPE', 'OUTLOOK', 'Outlook (Microsoft Graph)', 60);
    lv('STORAGE_TYPE', 'OBJECT_STORAGE', 'OCI Object Storage', 30);
    lv('STORAGE_TYPE', 'DATABASE', 'Database', 40);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
