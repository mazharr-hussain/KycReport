"""What the README of each COMMON component says beyond its file lists: purpose, usage, benefit, installation
requirements, privileges and the roles that get them at install, and how another application uses it. Descriptions,
privileges and install-time roles are taken from COMMON's own registration (19c seed_admin, 24, 26, 27)."""

ADMIN = 'Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.'
EVERY = 'every role, at install (each user then acts only on what the data and the task allow).'

C = {
 'home': dict(
    feature='COMMON_HOME', name='Common Home', module='Platform', actions='VIEW',
    purpose='The landing page of the COMMON application.',
    usage='Opened after sign-in to COMMON (page 1); a start point to the setup screens a user may open.',
    benefit='One entry point for IT and delegated administrators.',
    roles='Common Administrator (COMMON_HOME.VIEW, seed_common in 19c).',
    other='Not used by other applications.'),
 'applications': dict(
    feature='APPLICATIONS', name='Applications', module='Platform', actions='VIEW, CREATE, MANAGE',
    purpose='Registered applications, the common functions switched on for each, their setup.',
    usage='IT registers (onboards) every application here (pages 160, 166), defines setup types and levels (162, 163), '
          'chooses which common functions an application manages itself (164) and follows the application journey (165).',
    benefit='One register of every application: COMMON knows each application, its APEX ID and schema, and grants and '
            'scopes everything (security, setup, workflow) by it.',
    req='Script `db/admin/onboard-application.sql` (as XXFUSION) registers a new application; its schema then gets the grants.',
    roles=ADMIN,
    other='Before anything else an application is onboarded: `XXFND_APPLICATION_PKG.ONBOARD` (or `apex/db/admin/onboard-application.sql`) '
          'with its APEX application ID and code. That grants the application schema the COMMON objects (`XXFND_SHARE_PKG.GRANT_TO`); '
          'the application then creates synonyms for them (KYC: script 03). Its own pages call PAGE_ALLOWED / IS_DELEGATED to respect '
          'what IT lets it manage. Release 87: the application\'s own install can register it with the generic script '
          '`00c-onboard-with-common.sql` (XXFND_ONBOARD_PKG.ONBOARD_SELF; IT switch: COMMON setting ONBOARD_SELF_ALLOWED), and its '
          'navigation list for the common functions is `select * from xxfnd_app_menu_v where app_alias = :APP_ALIAS` (entries '
          'maintained here; the application adds its own with REGISTER_MENU_ENTRY). Release 88: every REGISTER_* routine has an '
          'UNREGISTER_* routine, and deleting a disabled application removes the setup it registered.'),
 'app-settings': dict(
    feature='APP_SETTINGS', name='Application Settings', module='Platform', actions='VIEW, MANAGE',
    purpose='Application settings.',
    usage='Pages 10022 / 10023 list and change the APEX application settings of the running application.',
    benefit='Settings are changed from the console, not in App Builder.',
    roles=ADMIN,
    other='An application declares its settings in its own application.apx (appSetting). COMMON issue C7: the screen changes the '
          'settings of the running application only.'),
 'optional-features': dict(
    feature='OPTIONAL_FEATURES', name='Optional Features', module='Platform', actions='VIEW, MANAGE',
    purpose='Optional features of each application, switched on or off.',
    usage='Pages 10020 / 10021 include or exclude an application\'s build options named "Feature - ...".',
    benefit='Parts of an application are switched on or off without a new release.',
    roles=ADMIN,
    other='An application defines build options named "Feature - <name>"; `XXFND_APP_SETTING_PKG.SET_FEATURE_STATUS` switches them.'),
 'platform-activity': dict(
    feature='PLATFORM_ACTIVITY', name='Platform Activity', module='Platform', actions='VIEW, MANAGE',
    purpose='Page views, top users, errors and page performance of every registered application (APEX activity log).',
    usage='Page 170, for IT.', benefit='One activity view for all applications instead of one report set per application.',
    req='The APEX activity log of the workspace.', roles='Common Administrator (27).',
    other='Nothing to do: every registered application appears.'),
 'usage-feedback': dict(
    feature='USAGE_FEEDBACK', name='Usage and Feedback', module='Platform', actions='VIEW, MANAGE',
    purpose='The feedback people gave on every registered application, and its follow-up.',
    usage='Pages 171 / 172: IT reads and follows up feedback.', benefit='Feedback from every application in one place.',
    req='APEX feedback of the workspace.', roles='Common Administrator (27).',
    other='The application links its Feedback entry to COMMON page 173 (Give Feedback).'),
 'give-feedback': dict(
    feature='GIVE_FEEDBACK', name='Give Feedback', module='Platform', actions='VIEW, CREATE',
    purpose='Everyone gives feedback on the page they are on, in any application.',
    usage='Page 173, opened from an application\'s navigation bar (with P173_APPLICATION_ID and P173_PAGE_ID).',
    benefit='One feedback form for all applications.', roles=f'Every role, at install (27).',
    other='Link to COMMON page 173 (`app: COMMON`) passing &APP_ID. and &APP_PAGE_ID. (or the entry Give '
          'Feedback of `XXFND_APP_MENU_V`); every signed-in user opens it (release 87).'),
 'data-model': dict(
    feature='DATA_MODEL', name='Data Model', module='Platform', actions='VIEW, MANAGE',
    purpose='The database objects of every registered application, read live from the database dictionary: the object '
            'catalogue and the entity-relationship diagram (release 89).',
    usage='Page 175 lists an application\'s objects (tables, views, packages, types, sequences, triggers) and sets its object '
          'prefix; page 176 shows one object (columns, constraints, indexes, triggers, routines with parameters, grants, uses / '
          'used by); page 177 draws the diagram of the application, a group of tables or one table with its neighbours.',
    benefit='Always current documentation of every application\'s data model, without exports or diagram tools.',
    req='To read other applications\' schemas, ADMIN runs `db/admin/grant-dictionary-to-xxfusion.sql` once (SELECT on the DBA_ '
        'dictionary views), then the supporting objects again; without it only COMMON\'s objects (and what COMMON may already '
        'read) are listed. The diagram uses the Mermaid library (a COMMON static file).',
    roles=ADMIN,
    other='Nothing to install in the application. IT may set its object prefix (page 175) and the application may group its '
          'tables for the diagram (`XXFND_DATA_MODEL_PKG.REGISTER_TABLE_GROUP`). Its administrators open it from the application\'s '
          'menu once IT lets the application manage Data Model (managed in the application): they see their own application only.'),
 'users-access': dict(
    feature='USERS_ACCESS', name='Users & Access', module='Security', actions='VIEW, CREATE, MANAGE',
    purpose='Users, their roles and their data access.',
    usage='Pages 103 / 104 maintain users (local or SSO, mapped to employees); page 183 assigns roles and data access rules. '
          'XXFND_USER_PKG is also every application\'s sign-in (post-authentication) and authorization logic.',
    benefit='One user record and one role assignment for all applications; sign-in and authorization rules in one place.',
    req='Single sign-on: the Fusion web credential and FUSION_BASE_URL (Fusion HCM worker sync).',
    roles=ADMIN,
    other='The application\'s authentication schemes call `XXFND_USER_PKG.POST_AUTH_LOCAL` / `POST_AUTH_SSO`, and its authorization '
          'schemes call `XXFND_USER_PKG.AUTHORIZED(<scheme>)` (KYC subscribes to them). The first administrator: '
          '`XXFND_USER_PKG.BOOTSTRAP_ADMIN`.'),
 'roles-privileges': dict(
    feature='ROLES_PRIVILEGES', name='Roles & Privileges', module='Security', actions='VIEW, CREATE, MANAGE',
    purpose='Roles, the privileges they grant and segregation of duties.',
    usage='Pages 105-108 and 182: roles, their privileges (feature x VIEW / CREATE / MANAGE), SoD rules.',
    benefit='Page access is data driven: every page is mapped to a feature and opened with the privilege on it; SoD is enforced '
            'once for all applications.',
    roles=ADMIN,
    other='The application registers its features, privileges, pages, roles and SoD rules with `REGISTER_FEATURE`, '
          '`REGISTER_PRIVILEGE`, `REGISTER_FEATURE_PAGE`, `REGISTER_ROLE`, `ADD_ROLE_PRIVILEGE`, `REGISTER_SOD_RULE` (KYC: 18h), '
          'and checks access with `HAS_PRIVILEGE`, `HAS_PAGE_PRIVILEGE`, `HAS_ROLE`. A registration never overrides what an '
          'administrator changed. `UNREGISTER_FEATURE_PAGE`, `UNREGISTER_FEATURE`, `UNREGISTER_PRIVILEGE`, `UNREGISTER_ROLE` '
          'remove the application\'s own rows (release 88).'),
 'data-security': dict(
    feature='DATA_SECURITY', name='Data Security', module='Security', actions='VIEW, CREATE, MANAGE',
    purpose='Data access rules: which rows each user and role can see.',
    usage='Pages 180 / 181: data access rules (table, column, allowed values), assigned to users and roles.',
    benefit='Row-level security (VPD) for every application from one set of rules.',
    roles=ADMIN,
    other='The application registers its rules with `XXFND_VPD_PKG.REGISTER_DATA_RULE`, applies the policies '
          '(`APPLY_POLICIES`, KYC script 03), reads `ALLOWED_VALUES` for its lists, and uses `BEGIN_TRUSTED` / `END_TRUSTED` '
          'around internal reads.'),
 'audit-log': dict(
    feature='AUDIT_LOG', name='Audit Log', module='Security', actions='VIEW',
    purpose='Who changed what and when.', usage='Page 111.', benefit='One audit trail for every application.',
    roles=ADMIN,
    other='The application creates audit triggers on its tables with `XXFND_AUDIT_PKG.CREATE_AUDIT_TRIGGER` and may set a change '
          'reason (`SET_CHANGE_REASON`).'),
 'lookups': dict(
    feature='LOOKUPS', name='Lookups', module='Reference Data', actions='VIEW, CREATE, MANAGE',
    purpose='Lists of values used across the application.', usage='Pages 101 / 102: lookup types and their values.',
    benefit='Lists of values are data, maintained from the console, with translations and levels.',
    roles=ADMIN,
    other='The application registers its lookup types and values with `XXFND_LOOKUP_PKG.REGISTER_LOOKUP_TYPE` / '
          '`REGISTER_LOOKUP_VALUE` (KYC: 18h) and reads them with `LOOKUP_MEANING`, `IS_VALID_LOOKUP` or the lookup views. '
          'It sees and maintains only its own lookups and the shared ones (release 87).'),
 'flexfields': dict(
    feature='FLEXFIELDS', name='Flexfields', module='Reference Data', actions='VIEW, CREATE, MANAGE',
    purpose='Descriptive flexfields and their value sets.', usage='Pages 150-153: value sets, flexfields, contexts, segments.',
    benefit='Extra fields on a record without a database change.',
    roles=ADMIN,
    other='The application registers its value sets, flexfields and contexts (`XXFND_DFF_PKG.REGISTER_VALUE_SET`, '
          '`REGISTER_FLEXFIELD`, `REGISTER_CONTEXT`), shows them with `RENDER`, checks with `VALIDATE` and saves with `SAVE`.'),
 'attachments': dict(
    feature='ATTACHMENTS', name='Attachments', module='Documents and Records', actions='VIEW, CREATE, MANAGE',
    purpose='Document categories, storage and where attachments appear.',
    usage='Pages 130-137: document entities, categories, attachment pages (who may change what, limits), storage per '
          'application and category.',
    benefit='One document store and one set of rules (types, sizes, permissions) for every application.',
    req='Documents are kept in the database until a server is set up (Integrations > Servers, Storage).',
    roles=ADMIN,
    other='The application registers its entities, categories and attachment pages (`XXFND_ATTACH_PKG.REGISTER_ENTITY`, '
          '`REGISTER_CATEGORY`, `REGISTER_ATTACHMENT_PAGE`; KYC: 18h), adds files with `ADD_FILE` / `ADD_TEXT`, moves them '
          'with `MOVE_DOCUMENTS`, and opens COMMON page 47 (Documents) for a record.'),
 'documents': dict(
    feature='DOCUMENTS', name='Documents', module='Documents and Records', actions='VIEW, CREATE, MANAGE',
    purpose="The documents of a record of any application: add, view, replace (the application's attachment page registration "
            'says who may change them).',
    usage='Pages 47 (Attachments of a record) and 48 (Document), opened from the application with the record\'s entity and key.',
    benefit='Applications need no document screens of their own.', roles='Every role, at install (27).',
    other='Link to COMMON page 47 (`app: COMMON`) with P47_APP_ALIAS, the source page, region, entity and key (KYC: pages 0 and '
          '211). Every signed-in user opens it (release 87) and sees only the records they may see.'),
 'retention': dict(
    feature='RETENTION', name='Retention', module='Documents and Records', actions='VIEW, CREATE, MANAGE',
    purpose='How long records and documents are kept.', usage='Pages 112 / 113: retention policies.',
    benefit='One retention rule set for every application.', roles=ADMIN,
    other='The application reads the policy that applies with `XXFND_RETENTION_PKG.POLICY_FOR` / `IS_ACTIVE`.'),
 'workflow-setup': dict(
    feature='WORKFLOW_SETUP', name='Workflow Setup', module='Workflow', actions='VIEW, CREATE, MANAGE',
    purpose='Delegations, deadlines and escalation, process catalogue.',
    usage='Pages 114 / 115 (delegations), 145 / 146 (task deadlines and escalation), 147 (process catalogue: which '
          'application workflows are switched on).',
    benefit='One workflow engine around APEX workflows and tasks: start / end / state, deadlines, delegations, notifications.',
    req='APEX workflows and human tasks; COMMON runs the task-deadlines automation for every application.',
    roles=ADMIN,
    other='The application registers its workflows as processes (`XXFND_WORKFLOW_PKG.SYNC_PROCESSES`, `SET_PROCESS_ENABLED`) and '
          'its task deadlines (`REGISTER_TASK_SETTING`), starts and ends them with `START_PROCESS` / `END_PROCESS`, and reads '
          '`STATE`, `IS_RUNNING`, `BUSINESS_ADMINS`.'),
 'approval-setup': dict(
    feature='APPROVAL_SETUP', name='Approval Setup', module='Workflow', actions='VIEW, CREATE, MANAGE',
    purpose='Approval rules: who approves which record, step by step.',
    usage='Pages 148 / 149: approval types and rules (conditions, steps, approvers).',
    benefit='Approval chains are data (AME style), not code.', roles=ADMIN,
    other='The application registers its approval types and default rule (`XXFND_APPROVAL_RULE_PKG.REGISTER_TYPE`, '
          '`REGISTER_DEFAULT_RULE`), starts an approval with `START_APPROVAL`, reads `CURRENT_APPROVERS` / `NEXT_STEP` and '
          'decides with `DECIDE_TASK`. Several rules per type: `REGISTER_RULE` (release 88); `UNREGISTER_RULE` / `UNREGISTER_TYPE` '
          'remove them.'),
 'change-approvals': dict(
    feature='CHANGE_APPROVALS', name='Configuration Change Approvals', module='Workflow', actions='VIEW, MANAGE',
    purpose='Who approves the configuration changes of every application (maker-checker, process CONFIG_CHANGE).',
    usage='A change to a controlled setup table waits for approval; the approver acts on COMMON page 144 from My Tasks.',
    benefit='Maker-checker on setup data for every application without code in the application.',
    roles='The roles that manage the Approval Setup, once at install (26).',
    other='The application registers its controlled setup tables with `XXFND_APPROVAL_PKG.REGISTER_CONFIG_TABLE` and submits a '
          'change with `REQUEST` (release 87: a faulted earlier change no longer blocks it).'),
 'my-tasks': dict(
    feature='MY_TASKS', name='My Tasks', module='Workflow', actions='VIEW, MANAGE',
    purpose='The tasks of the signed-in user from every application.',
    usage='Page 40 (the task list), 43 (notifications), 143 (answer / review an information request), 144 (configuration change).',
    benefit='One inbox for all applications.', roles=EVERY,
    other='Link to COMMON page 40 (`app: COMMON`, or the entry My Tasks of `XXFND_APP_MENU_V`); the tasks of the application\'s '
          'workflows appear by themselves. Every signed-in user opens it (release 87) and sees only their own tasks.'),
 'workflow-monitor': dict(
    feature='WORKFLOW_MONITOR', name='Workflow Monitor', module='Workflow', actions='VIEW, MANAGE',
    purpose="Running workflows and tasks of every application: act on anyone's behalf.",
    usage='Pages 141 / 142: suspend, resume, retry, reassign, delegate.',
    benefit='Business administration of every workflow from one place.',
    roles='Super Administrator (SUPER_ADMIN); granted from the console only (19c).',
    other='Nothing to register: the workflows of every application appear. `XXFND_WORKFLOW_PKG.BUSINESS_ADMINS` returns the holders.'),
 'information-requests': dict(
    feature=None, name='Information Requests (RFI)', module='Workflow', actions='-',
    purpose='Asking someone (a colleague or an outside person) for information on a record, with the answer loop (RFI workflow).',
    usage='The RFI is created by the application; the answer is given on COMMON page 143 (from My Tasks) or, by an outside '
          'person, on the public page 50 with a one-time link.',
    benefit='One RFI process, with e-mail and an answer page, for every application.',
    req='The RFI process switched on for the application (Workflow Setup > Process Catalogue); e-mail for outside people.',
    roles='No feature of its own: answering uses My Tasks; the public page 50 needs no sign-in (a one-time token).',
    other='The application creates an RFI with `XXFND_RFI_PKG.CREATE_RFI` (entity, key, recipient), sends the link with '
          '`SEND_EMAIL`, and reads `OPEN_COUNT` / `IS_WAITING`. Page 143 keeps the RFI\'s documents and the answer is due on '
          'the RFI\'s due date (release 88).'),
 'notifications': dict(
    feature='NOTIFICATIONS', name='Notifications', module='Workflow', actions='VIEW, CREATE, MANAGE',
    purpose='E-mail and in-app notification templates.',
    usage='Pages 109 / 110 (templates), 116 (delivery rules: e-mail, in-app, push), 117 (log).',
    benefit='Notifications are templates and rules (data), sent the same way for every application.',
    req='APEX e-mail (SMTP) for e-mail; settings MAIL_FROM and MAIL_FOOTER of COMMON.',
    roles=ADMIN,
    other='The application registers its templates with `XXFND_NOTIFY_PKG.REGISTER_TEMPLATE` (KYC: KYC_ALERT) and sends with '
          '`SEND`, `SEND_TO_USERS` or `RAISE_EVENT`.'),
 'communications': dict(
    feature='COMMUNICATIONS', name='Communications', module='Workflow', actions='VIEW, CREATE, MANAGE',
    purpose='The e-mails with outside people of a record of any application: send, record a received one, history.',
    usage='Page 45 (history of a record) and 46 (E-mail), opened from the application.',
    benefit='One e-mail history for every record, with its files, without e-mail screens in the application.',
    req='APEX e-mail (SMTP).',
    roles='Every role: VIEW and CREATE; MANAGE (record a received e-mail): the roles that manage the notifications (26).',
    other='Link to COMMON page 46 (`app: COMMON`) for the record (KYC: page 211); `XXFND_NOTIFY_PKG.RECORD_SENT` / '
          '`RECORD_RECEIVED` store them (only for the application\'s own records). Every signed-in user opens the pages (release 87). '
          'The record\'s contacts are offered as recipients when the application registers a contact source '
          '(`REGISTER_CONTACT_SOURCE`: a view of its schema with PK1_VALUE, CONTACT_NAME, EMAIL_ADDRESS, SELECT granted to COMMON).'),
 'integrations': dict(
    feature='INTEGRATIONS', name='Integrations', module='Integrations', actions='VIEW, CREATE, MANAGE',
    purpose='Endpoints, purposes and the transmission log.',
    usage='Pages 120 / 121 (servers), 122 / 123 (integration purposes), 124 / 125 (transmission log, a call).',
    benefit='Every outbound call is logged and can be retried; servers and credentials are set up once.',
    req='APEX web credentials and remote servers of the workspace; Fusion HCM sync needs FUSION_BASE_URL and its credential.',
    roles=ADMIN,
    other='The application registers its purposes with `XXFND_INTEGRATION_PKG.REGISTER_PURPOSE` (KYC: 18h) and calls a service '
          'with `CALL` (logged, retried with `RETRY`).'),
}

COMMON_REQ = ('COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites '
              'check 00a first; 00b stops an install in the wrong schema).')
OTHER_APP = ('1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). '
             '2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the '
             'COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON '
             'data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type '
             '"page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles '
             'in the COMMON console.')
