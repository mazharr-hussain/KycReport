--------------------------------------------------------------------------------
-- 09d XXFND_APPLICATION_PKG - the Applications component of Platform (release 80: one package).
--   Release 72/73: XXFND_APPLICATION_FUNCTIONS (per application and common function: managed in the application).
--   Release 73: setup types (two levels like profile options: the instance and an application; XXFND_SETUP_TYPES,
--   XXFND_SETUP_TYPE_APPS) - the tables move here from 21c in release 80, created only when missing.
--   Release 80 merges XXFND_APP_FUNCTION_PKG, XXFND_SETUP_TYPE_PKG and XXFND_ADMIN_SCOPE_PKG into
--   XXFND_APPLICATION_PKG (the old packages are dropped by 21c; old callers break on purpose: no wrappers).
--   The scope policies and <table>_SC triggers are (re)created by 16i, the <table>_LV triggers by 21c.
--   Release 87: the menu of every application (XXFND_APP_MENU_ENTRIES, made by ONBOARD, read through XXFND_APP_MENU_V);
--   the caller rule of every registration routine (REGISTERED_CODE: an application changes only its own rows); the
--   setup of another application is hidden from an application (scope policy, SQL issued by the application).
--   COMMON only. Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXFND_APPLICATION_FUNCTIONS', q'~create table xxfnd_application_functions (
    application_code       varchar2(30)   not null,
    feature_code           varchar2(30)   not null,
    enabled_flag           varchar2(1)    default 'N' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_application_functions_pk primary key (application_code, feature_code),
    constraint xxfnd_application_functions_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade,
    constraint xxfnd_application_functions_fk2 foreign key (feature_code)
        references xxfnd_features (feature_code) on delete cascade,
    constraint xxfnd_application_functions_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_application_functions is 'Common functions (COMMON admin features) switched on per application by IT; XXFND_APPLICATION_PKG.IS_MANAGED.'~');
    end if;
    -- release 73: no "Available" switch any more (every common function works for every application); instead
    -- IT lets an application's administrators maintain the function's setup for their application themselves
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATION_FUNCTIONS', 'MANAGED_IN_APP_FLAG', q'~varchar2(1) default 'N' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPLICATION_FUNCTIONS', 'XXFND_APPLICATION_FUNCTIONS_CK2',
                                 q'~check (managed_in_app_flag in ('Y','N'))~');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPLICATION_FUNCTIONS', 'XXFND_APPLICATION_FUNCTIONS_CK1');
    xxfnd_ddl_pkg.drop_column('XXFND_APPLICATION_FUNCTIONS', 'ENABLED_FLAG');
    xxfnd_ddl_pkg.run(q'~comment on table xxfnd_application_functions is 'Common functions per application: MANAGED_IN_APP_FLAG Y = the application''s administrators maintain its setup for their application (XXFND_APPLICATION_PKG.IS_MANAGED).'~');
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPLICATION_FUNCTIONS');
end;
/

-- release 87: the menu each application shows for the common functions (entries made by ONBOARD, maintained in COMMON)
begin
    if xxfnd_ddl_pkg.create_table('XXFND_APP_MENU_ENTRIES', q'~create table xxfnd_app_menu_entries (
    application_code       varchar2(30)   not null,
    entry_code             varchar2(60)   not null,
    label                  varchar2(100)  not null,
    parent_code            varchar2(60),
    display_sequence       number         default 100 not null,
    icon_css               varchar2(100),
    target_type            varchar2(20)   not null,
    page_id                number,
    feature_code           varchar2(30),
    enabled_flag           varchar2(1)    default 'Y' not null,
    made_by                varchar2(10)   default 'COMMON' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_app_menu_entries_pk primary key (application_code, entry_code),
    constraint xxfnd_app_menu_entries_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade,
    constraint xxfnd_app_menu_entries_ck1 check (target_type in ('COMMON_PAGE', 'APP_PAGE', 'MANAGED', 'SHARED_SETUP')),
    constraint xxfnd_app_menu_entries_ck2 check (enabled_flag in ('Y','N')),
    constraint xxfnd_app_menu_entries_ck3 check (made_by in ('COMMON','APP')),
    constraint xxfnd_app_menu_entries_ck4 check (target_type in ('MANAGED', 'SHARED_SETUP') or page_id is not null)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_app_menu_entries is 'The menu entries of each application for the common functions (release 87): made by XXFND_APPLICATION_PKG.ONBOARD / ENSURE_MENU or the application (REGISTER_MENU_ENTRY), maintained in COMMON; read through XXFND_APP_MENU_V.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_app_menu_entries.target_type is 'COMMON_PAGE: a COMMON page; APP_PAGE: a page of the application; MANAGED: a common function the application manages (COMMON page 99 for the application); SHARED_SETUP: COMMON Administration (page 100).'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_app_menu_entries.feature_code is 'The feature whose VIEW privilege shows the entry; empty = every signed-in user.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_APP_MENU_ENTRIES');
end;
/

declare
    l_new boolean;
begin
    l_new := xxfnd_ddl_pkg.create_table('XXFND_SETUP_TYPES', q'~create table xxfnd_setup_types (
    setup_type_code        varchar2(30)   not null,
    setup_type_name        varchar2(100)  not null,
    feature_code           varchar2(30),
    table_name             varchar2(128),
    list_page_id           number,
    form_page_id           number,
    allowed_level          varchar2(1)    default 'B' not null,
    all_applications_flag  varchar2(1)    default 'Y' not null,
    display_sequence       number         default 100 not null,
    description            varchar2(400),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_setup_types_pk primary key (setup_type_code),
    constraint xxfnd_setup_types_ck1 check (allowed_level in ('I','A','B')),
    constraint xxfnd_setup_types_ck2 check (all_applications_flag in ('Y','N'))
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_setup_types is 'Setup types and the level they are kept at: I instance only (application empty), A application only, B either; ALL_APPLICATIONS_FLAG N = only the applications in XXFND_SETUP_TYPE_APPS.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_SETUP_TYPES');

    if xxfnd_ddl_pkg.create_table('XXFND_SETUP_TYPE_APPS', q'~create table xxfnd_setup_type_apps (
    setup_type_code        varchar2(30)   not null,
    application_code       varchar2(30)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_setup_type_apps_pk primary key (setup_type_code, application_code),
    constraint xxfnd_setup_type_apps_fk1 foreign key (setup_type_code)
        references xxfnd_setup_types (setup_type_code) on delete cascade,
    constraint xxfnd_setup_type_apps_fk2 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_setup_type_apps is 'Applications a setup type may be kept for (when its ALL_APPLICATIONS_FLAG is N).'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_SETUP_TYPE_APPS');
end;
/

create or replace package xxfnd_application_pkg authid definer as

    ----------------------------------------------------------------------------
    -- Applications and their common functions (was XXFND_APP_FUNCTION_PKG)
    ----------------------------------------------------------------------------
    -- release 73: Y when IT lets the application's administrators maintain the common function's setup for their
    -- application (from the application's menu), else N.
    function is_managed(p_application_code in varchar2, p_feature_code in varchar2) return varchar2;
    -- One row per common function for the application (not managed in the application), so IT only flips switches.
    procedure ensure_rows(p_application_code in varchar2);
    -- The common functions: the admin features with a COMMON setup page (not Applications itself).
    function common_functions return apex_t_varchar2;
    -- Registration (page 161): grants on the shared objects to the application's schema, its APEX ID and the
    -- function rows.
    procedure register_application(p_application_code in varchar2);
    -- release 73: the application's APEX ID in this environment, from its alias (APEX applications of the
    -- workspace); also set at its sign-in (09b). Nothing when the application is not installed yet.
    procedure set_apex_id(p_application_code in varchar2);

    ----------------------------------------------------------------------------
    -- Setup types (was XXFND_SETUP_TYPE_PKG)
    ----------------------------------------------------------------------------
    -- Y when a row of the setup type may belong to the application; null application = the instance level.
    function app_allowed(p_setup_type_code in varchar2, p_application_code in varchar2) return varchar2;
    -- The setup type of a COMMON page (its list or form page), else null.
    function page_type(p_page_id in number) return varchar2;
    -- Raises ORA-20160 when the application is not allowed for the setup type of the table. Only on the
    -- application screens (not during installs, jobs or scripts).
    procedure check_level(p_table_name in varchar2, p_application_code in varchar2);
    -- The <table>_LV triggers on every setup type table with an APPLICATION_CODE column.
    procedure create_triggers;
    -- Release 80: the applications a setup type may be kept for (page 163). Only used when the type is not instance
    -- only and not for every application; otherwise the list is emptied. P_APPLICATIONS: colon-separated codes.
    procedure save_setup_type_apps(p_setup_type_code in varchar2, p_allowed_level in varchar2,
                                   p_all_applications_flag in varchar2, p_applications in varchar2);

    ----------------------------------------------------------------------------
    -- Administration scope (was XXFND_ADMIN_SCOPE_PKG)
    ----------------------------------------------------------------------------
    -- Y when the user holds the active role COMMON_ADMIN (administers every application).
    function is_common_admin(p_user_name in varchar2 default null) return varchar2;
    -- Y when the user may administer the application (application code); null code = shared rows: Common Administrator only.
    function can_administer(p_application_code in varchar2, p_user_name in varchar2 default null) return varchar2;
    -- Y when the user administers at least one application (may use the COMMON application).
    function administers_any(p_user_name in varchar2 default null) return varchar2;
    -- The application filter a COMMON screen opens with (release 71): the requested application, else ALL.
    function default_application(p_requested in varchar2 default null) return varchar2;
    -- DBMS_RLS policy functions (policy XXFND_ADMIN_SCOPE on the setup tables with APPLICATION_CODE). Only inside the
    -- COMMON application (release 71: IT only): nothing for anyone but a Common Administrator; G_ADMIN_APP = ALL:
    -- every row; one application: its rows and the shared rows. Other applications and code outside APEX: no limit.
    function policy_read(p_schema in varchar2, p_object in varchar2) return varchar2;
    function policy_change(p_schema in varchar2, p_object in varchar2) return varchar2;
    -- The setup tables scoped by application (policies and the default-application trigger).
    function scoped_tables return apex_t_varchar2;
    -- APEX application ID of an application (code; recorded at its sign-in), else the running application.
    function apex_app_id(p_application_code in varchar2) return number;
    -- release 68: link to a setup page from a business application - the page in the running application when it
    -- has it, otherwise the page in COMMON (entry page 99), opened for the running application (locked to it).
    function setup_page_url(p_page_id in number) return varchar2;
    -- release 72: Y when the running application has the page (menus show only an application's own pages).
    function local_page(p_page_id in number) return varchar2;
    -- release 73: delegated administration. Y when IT lets the application's administrators maintain the common
    -- function (XXFND_APPLICATION_FUNCTIONS.MANAGED_IN_APP_FLAG) and the user holds a privilege on it through an
    -- active role of that application.
    function is_delegated(p_application_code in varchar2, p_feature_code in varchar2,
                          p_user_name in varchar2 default null) return varchar2;
    -- Y when the user is delegated for at least one function of any application (may open COMMON's delegated screens).
    function delegated_any(p_user_name in varchar2 default null) return varchar2;
    -- The application a delegated COMMON screen works for: G_ADMIN_APP when the application opened it for itself
    -- (G_ADMIN_LOCK = Y, page 99) and the user is delegated for it; else null.
    function delegated_app return varchar2;
    -- Y when the user may open the COMMON page: a Common Administrator any page; a delegated user only the pages of
    -- a function managed in the application that opened it.
    function page_allowed(p_page_id in number) return varchar2;
    -- release 73: a menu entry of the running application for a common function managed in it: null when not
    -- delegated. Release 87: COMMON page 99 opened for the application (was the application's page 98).
    function delegated_url(p_feature_code in varchar2) return varchar2;

    ----------------------------------------------------------------------------
    -- Release 85: feedback of every application, kept by APEX (APEX_TEAM_FEEDBACK), given and followed up in COMMON
    ----------------------------------------------------------------------------
    -- Feedback on a page of a registered application (P_TYPE 1 comment, 2 enhancement, 3 bug). Refused (ORA-20171)
    -- for an application that is not registered.
    procedure submit_feedback(p_application_id in number, p_page_id in number, p_type in number, p_comment in varchar2);
    -- A follow-up on a feedback (USAGE_FEEDBACK - Manage, ORA-20172 otherwise).
    procedure feedback_follow_up(p_feedback_id in number, p_follow_up in varchar2);

    ----------------------------------------------------------------------------
    -- Release 86: onboarding an application and the registration rule every REGISTER_* routine uses
    ----------------------------------------------------------------------------
    -- The registered application code (upper case); catalogue error XXFND_APP_NOT_REGISTERED (ORA-20180) when the
    -- code is not in XXFND_APPLICATIONS. No APEX session needed.
    function registered_code(p_application_code in varchar2) return varchar2;
    -- The same, as stored in a setup row: COMMON is the instance (null), any other application its code.
    function setup_code(p_application_code in varchar2) return varchar2;
    -- A setup row that already exists under another application is refused (XXFND_REG_OTHER_APP, ORA-20186):
    -- P_ROW_APPLICATION is the row's application (null = instance row, open to every application).
    procedure assert_same_application(p_what in varchar2, p_key in varchar2, p_row_application in varchar2,
                                      p_application_code in varchar2);
    -- Release 88 (C8, C9): removes one registered setup row of P_APPLICATION_CODE (the UNREGISTER_* routine of the
    -- component that owns P_TABLE calls it; nothing else does). P_KEY_COLUMNS / P_KEYS: the row's key (1 to 3
    -- columns); P_OWNER_SQL: the expression on the row (alias T) that gives its application code (null = COMMON).
    -- ORA-20187 when the row is not registered, ORA-20186 when it belongs to another application (or to COMMON),
    -- ORA-20196 when business data still uses it (nothing is removed then).
    procedure remove_registered(p_application_code in varchar2,
                                p_what             in varchar2,
                                p_table            in varchar2,
                                p_key_columns      in apex_t_varchar2,
                                p_keys             in apex_t_varchar2,
                                p_owner_sql        in varchar2 default 't.application_code');
    -- Release 88 (C9): removes every row of P_TABLE that belongs to P_APPLICATION_CODE (P_OWNER_SQL as above): the
    -- UNREGISTER_APPLICATION routine of the owning component calls it for DELETE_APPLICATION. ORA-20196 when business
    -- data still uses one of them (nothing is removed then). Never for COMMON.
    procedure remove_all_registered(p_application_code in varchar2,
                                    p_what             in varchar2,
                                    p_table            in varchar2,
                                    p_owner_sql        in varchar2 default 't.application_code');
    -- Release 88: removes an entry an application added to its menu (REGISTER_MENU_ENTRY); COMMON's entries are
    -- switched off on page 166 instead.
    procedure unregister_menu_entry(p_application_code in varchar2, p_entry_code in varchar2);
    -- Creates (= registers: grants to its schema, APEX ID, function and process rows) or updates an application.
    -- Name, alias and parsing schema come from the APEX application P_APEX_APPLICATION_ID of the current workspace;
    -- refused when that APEX application is not in the workspace (ORA-20181) or is registered under another code
    -- (ORA-20182). In an APEX session: Applications - Manage.
    procedure save_application(p_application_code    in varchar2,
                               p_apex_application_id in number,
                               p_description         in varchar2 default null,
                               p_enabled_flag        in varchar2 default 'Y',
                               p_email_enabled_flag  in varchar2 default 'Y');
    -- SAVE_APPLICATION + the role <CODE>_ADMIN (every privilege of the application's features) given to
    -- P_ADMIN_USER when named; the shared functions are not managed in the application and the shared processes
    -- (e.g. RFI) start off; the default notification rules (for every application) apply; documents are kept in
    -- the database until storage is set up. Re-runnable: what the administrators changed is kept.
    procedure onboard(p_apex_application_id in number,
                      p_application_code    in varchar2,
                      p_description         in varchar2 default null,
                      p_email_enabled_flag  in varchar2 default 'Y',
                      p_admin_user          in varchar2 default null);
    -- Enables or disables an application (COMMON is always enabled).
    procedure set_enabled(p_application_code in varchar2, p_enabled_flag in varchar2);
    -- Null when the application may be deleted; otherwise the reason. Only a disabled application that no business
    -- data refers to (tasks, workflows, RFIs, communications, documents, notifications, roles in use ...); release 88
    -- (C9): the setup it registered does not block.
    function delete_blocker(p_application_code in varchar2) return varchar2;
    -- Deletes the application with the setup it registered (each component's UNREGISTER_APPLICATION) and its own
    -- standard rows (function and process rows, unused roles); raises the DELETE_BLOCKER reason (ORA-20184) when it
    -- may not be deleted, ORA-20196 when business data still uses a setup row.
    procedure delete_application(p_application_code in varchar2);
    -- The common functions managed in the application (P_MANAGED_FEATURES: colon-separated feature codes); every
    -- other common function is not (was the "save functions" grid of page 161).
    procedure save_functions(p_application_code in varchar2, p_managed_features in varchar2);

    ----------------------------------------------------------------------------
    -- Release 87: the menu of an application for the common functions
    ----------------------------------------------------------------------------
    -- The default entries of an application (My Tasks, Notifications, Feedback, Shared Setup, one entry per common
    -- function shown when the application manages it); only what is missing, so what IT changed is kept. Called by
    -- ONBOARD and SAVE_FUNCTIONS.
    procedure ensure_menu(p_application_code in varchar2);
    -- An application's own entry (made from its install): added when missing, never changed afterwards.
    -- P_TARGET_TYPE: COMMON_PAGE, APP_PAGE, MANAGED or SHARED_SETUP; P_FEATURE_CODE: whose VIEW privilege shows it
    -- (empty = every signed-in user). The caller must be the application (REGISTERED_CODE).
    procedure register_menu_entry(p_application_code in varchar2,
                                  p_entry_code       in varchar2,
                                  p_label            in varchar2,
                                  p_target_type      in varchar2,
                                  p_page_id          in number   default null,
                                  p_feature_code     in varchar2 default null,
                                  p_icon_css         in varchar2 default null,
                                  p_display_sequence in number   default null,
                                  p_parent_code      in varchar2 default null);
    -- IT changes an entry (label, order, icon, on / off) on the Application page (166). Applications - Manage.
    procedure save_menu_entry(p_application_code in varchar2,
                              p_entry_code       in varchar2,
                              p_label            in varchar2,
                              p_display_sequence in number,
                              p_icon_css         in varchar2,
                              p_enabled_flag     in varchar2);
    -- Release 104: the application's menu, kept here for every application (as an EBS / Fusion menu): entries are
    -- folders (FOLDER, a parent of other entries) or what opens a page - APP_PAGE (a page of the application),
    -- ADMIN_PAGE (a page of the application for its administrators, e.g. its Administration page), COMMON_PAGE,
    -- MANAGED, SHARED_SETUP. MAINTAIN_MENU_ENTRY adds an entry (made by ADMIN) or changes one (any
    -- maker; the code and the maker stay); a parent must be a folder of the same application. DELETE_MENU_ENTRY
    -- removes an entry an administrator added (with the entries inside it); entries made by COMMON or the application
    -- are hidden instead. Applications privileges (Manage).
    procedure maintain_menu_entry(p_application_code in varchar2,
                                  p_entry_code       in varchar2,
                                  p_label            in varchar2,
                                  p_parent_code      in varchar2,
                                  p_display_sequence in number,
                                  p_icon_css         in varchar2,
                                  p_target_type      in varchar2,
                                  p_page_id          in number,
                                  p_feature_code     in varchar2,
                                  p_enabled_flag     in varchar2);
    procedure delete_menu_entry(p_application_code in varchar2, p_entry_code in varchar2);
    -- Release 104: Y when the signed-in user sees the entry - the same privileges as the pages: the entry's feature
    -- (View), else for an application page the feature the page belongs to (View; a page of no feature: every user),
    -- a folder when one of its entries is seen (XXFND_NAV_MENU_V).
    function entry_visible(p_application_code in varchar2, p_target_type in varchar2, p_page_id in number,
                           p_feature_code in varchar2, p_enabled_flag in varchar2) return varchar2;
    -- For XXFND_APP_MENU_V: Y when the signed-in user sees the entry; the link of the entry.
    function menu_visible(p_application_code in varchar2, p_target_type in varchar2, p_feature_code in varchar2,
                          p_enabled_flag in varchar2) return varchar2;
    function menu_url(p_application_code in varchar2, p_target_type in varchar2, p_page_id in number,
                      p_feature_code in varchar2) return varchar2;
end xxfnd_application_pkg;
/

create or replace package body xxfnd_application_pkg as


    function is_managed(p_application_code in varchar2, p_feature_code in varchar2) return varchar2 is
        l_flag xxfnd_application_functions.managed_in_app_flag%type;
    begin
        select max(managed_in_app_flag) into l_flag
          from xxfnd_application_functions
         where application_code = upper(p_application_code) and feature_code = upper(p_feature_code);
        return nvl(l_flag, 'N');
    end is_managed;

    function common_functions return apex_t_varchar2 is
        l_codes apex_t_varchar2;
    begin
        -- the admin features with a COMMON setup page (not the registration itself)
        select distinct f.feature_code bulk collect into l_codes
          from xxfnd_features f
          join xxfnd_feature_pages fp on fp.feature_code = f.feature_code and fp.app_alias = 'COMMON'
         where f.admin_flag = 'Y' and f.feature_code <> 'APPLICATIONS';
        return l_codes;
    end common_functions;

    procedure ensure_rows(p_application_code in varchar2) is
    begin
        insert into xxfnd_application_functions (application_code, feature_code, managed_in_app_flag)
        select upper(p_application_code), f.feature_code, 'N'
          from xxfnd_features f
         where f.feature_code in (select column_value from table(common_functions))
           and not exists (select 1 from xxfnd_application_functions x
                            where x.application_code = upper(p_application_code) and x.feature_code = f.feature_code);
    end ensure_rows;

    procedure set_apex_id(p_application_code in varchar2) is
    begin
        update xxfnd_applications a
           set a.apex_application_id = (select max(x.application_id) from apex_applications x
                                         where upper(x.alias) = upper(a.apex_app_alias))
         where a.application_code = upper(p_application_code)
           and exists (select 1 from apex_applications x where upper(x.alias) = upper(a.apex_app_alias))
           and decode(a.apex_application_id, (select max(x.application_id) from apex_applications x
                                               where upper(x.alias) = upper(a.apex_app_alias)), 0, 1) = 1;
    end set_apex_id;

    procedure register_application(p_application_code in varchar2) is
        l_schema xxfnd_applications.schema_name%type;
        l_n      pls_integer;
    begin
        select max(schema_name) into l_schema from xxfnd_applications where application_code = upper(p_application_code);
        select count(*) into l_n from all_users where username = upper(l_schema);
        if l_n > 0 and upper(l_schema) <> user then
            -- XXFND_SHARE_PKG is installed later (19c): called by name
            execute immediate 'call xxfnd_share_pkg.grant_to(:s)' using upper(l_schema);
        end if;
        set_apex_id(p_application_code);
        ensure_rows(p_application_code);
    end register_application;


    function app_allowed(p_setup_type_code in varchar2, p_application_code in varchar2) return varchar2 is
        l_level xxfnd_setup_types.allowed_level%type;
        l_all   xxfnd_setup_types.all_applications_flag%type;
        l_n     pls_integer;
    begin
        select max(allowed_level), max(all_applications_flag) into l_level, l_all
          from xxfnd_setup_types where setup_type_code = upper(p_setup_type_code);
        if l_level is null then
            return 'Y';   -- not a setup type: no rule
        elsif p_application_code is null then
            return case when l_level in ('I', 'B') then 'Y' else 'N' end;
        elsif l_level = 'I' or upper(p_application_code) = 'COMMON' then
            return 'N';
        elsif l_all = 'Y' then
            return 'Y';
        end if;
        select count(*) into l_n from xxfnd_setup_type_apps
         where setup_type_code = upper(p_setup_type_code) and application_code = upper(p_application_code);
        return case when l_n > 0 then 'Y' else 'N' end;
    end app_allowed;

    function page_type(p_page_id in number) return varchar2 is
        l_code xxfnd_setup_types.setup_type_code%type;
    begin
        select max(setup_type_code) into l_code from xxfnd_setup_types
         where p_page_id in (list_page_id, form_page_id);
        return l_code;
    end page_type;

    procedure check_level(p_table_name in varchar2, p_application_code in varchar2) is
    begin
        if not xxfnd_util_pkg.in_apex_session then
            return;
        end if;
        for t in (select setup_type_code, setup_type_name, allowed_level from xxfnd_setup_types
                   where table_name = upper(p_table_name)) loop
            if app_allowed(t.setup_type_code, p_application_code) = 'N' then
                raise_application_error(-20160, t.setup_type_name || ': ' ||
                    case when p_application_code is null then 'choose an application (application level only).'
                         when t.allowed_level = 'I' then 'kept for the whole workspace (all applications) only.'
                         else 'not available for ' || upper(p_application_code) || '.' end);
            end if;
        end loop;
    end check_level;

    procedure create_triggers is
    begin
        for t in (select distinct s.table_name from xxfnd_setup_types s
                   where s.table_name is not null
                     and exists (select 1 from user_tab_columns c
                                  where c.table_name = s.table_name and c.column_name = 'APPLICATION_CODE')) loop
            execute immediate 'create or replace trigger ' || substr(t.table_name, 1, 120) || '_LV
                before insert or update of application_code on ' || t.table_name || '
                for each row
            begin
                -- release 73 (21c): the level the setup type is kept at (XXFND_SETUP_TYPES)
                if inserting or nvl(:new.application_code, ''#'') <> nvl(:old.application_code, ''#'') then
                    xxfnd_application_pkg.check_level(''' || t.table_name || ''', :new.application_code);
                end if;
            end;';
        end loop;
    end create_triggers;

    procedure save_setup_type_apps(p_setup_type_code in varchar2, p_allowed_level in varchar2,
                                   p_all_applications_flag in varchar2, p_applications in varchar2) is
    begin
        delete from xxfnd_setup_type_apps where setup_type_code = upper(p_setup_type_code);
        if p_allowed_level <> 'I' and p_all_applications_flag = 'N' then
            insert into xxfnd_setup_type_apps (setup_type_code, application_code)
            select upper(p_setup_type_code), column_value from table(apex_string.split(p_applications, ':'))
             where column_value is not null;
        end if;
    end save_setup_type_apps;


    function norm_user(p_user_name in varchar2) return varchar2 is
    begin
        return upper(nvl(p_user_name, xxfnd_util_pkg.current_user));
    end norm_user;

    function is_common_admin(p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        select count(*) into l_n
          from xxfnd_user_roles_v
         where user_name = l_user and role_code = 'COMMON_ADMIN' and active_flag = 'Y';
        return case when l_n > 0 then 'Y' else 'N' end;
    end is_common_admin;

    function can_administer(p_application_code in varchar2, p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        if is_common_admin(p_user_name) = 'Y' then
            return 'Y';
        end if;
        if p_application_code is null then
            return 'N';
        end if;
        select count(*) into l_n
          from xxfnd_user_roles_v ur
          join xxfnd_role_privileges rp on rp.role_code = ur.role_code
          join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
          join xxfnd_features f         on f.feature_code = p.feature_code
         where ur.user_name = l_user
           and ur.active_flag = 'Y'
           and ur.application_code = upper(p_application_code)
           and f.admin_flag = 'Y'
           and f.enabled_flag = 'Y'
           and rownum = 1;
        return case when l_n > 0 then 'Y' else 'N' end;
    end can_administer;

    function administers_any(p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        if is_common_admin(p_user_name) = 'Y' then
            return 'Y';
        end if;
        select count(*) into l_n
          from xxfnd_user_roles_v ur
          join xxfnd_role_privileges rp on rp.role_code = ur.role_code
          join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
          join xxfnd_features f         on f.feature_code = p.feature_code
         where ur.user_name = l_user
           and ur.active_flag = 'Y' and f.admin_flag = 'Y' and f.enabled_flag = 'Y'
           and rownum = 1;
        return case when l_n > 0 then 'Y' else 'N' end;
    end administers_any;

    function default_application(p_requested in varchar2 default null) return varchar2 is
        l_n pls_integer;
    begin
        -- release 71: ALL (every application) unless a registered application is requested
        if p_requested is null or upper(p_requested) = 'ALL' then
            return 'ALL';
        end if;
        select count(*) into l_n from xxfnd_applications where application_code = upper(p_requested);
        return case when l_n > 0 then upper(p_requested) else 'ALL' end;
    end default_application;

    function in_common return boolean is
    begin
        return nvl(upper(v('APP_ALIAS')), '#') = 'COMMON';   -- false (not null) outside APEX
    end in_common;

    -- release 71: COMMON is for IT (Common Administrator) only. G_ADMIN_APP is a view filter there: ALL (default) =
    -- every application's rows, one application = its rows and the shared rows.
    -- release 73: no application filter for IT (G_ADMIN_APP = ALL), unless an application opened the screen for
    -- itself (its rows and the instance rows). A delegated user (not IT): reads the application's rows and the
    -- instance rows, changes only the application's rows.
    -- release 87: who issued the call into COMMON. Walks the call stack past this package: COMMON's own code
    -- (P_KIND COMMON), an APEX page, process or job (APEX: the application is v('APP_ID'); in App Builder the
    -- application being worked on, FB_FLOW_ID), or the database code of a schema / the session's schema (SCHEMA).
    -- P_ANY_COMMON: any other COMMON unit on the way counts as COMMON (the scope policy); else COMMON units are passed.
    procedure caller(p_kind out varchar2, p_value out varchar2, p_any_common in boolean) is
        l_owner varchar2(128);
    begin
        for i in 2 .. utl_call_stack.dynamic_depth loop
            l_owner := utl_call_stack.owner(i);
            if l_owner = $$PLSQL_UNIT_OWNER then
                if p_any_common and utl_call_stack.subprogram(i)(1) <> 'XXFND_APPLICATION_PKG' then
                    p_kind := 'COMMON';
                    return;
                end if;
            elsif l_owner like 'APEX\_%' escape '\' or l_owner = 'SYS' then
                p_kind := 'APEX';
                return;
            elsif l_owner is not null then
                p_kind := 'SCHEMA';
                p_value := l_owner;
                return;
            end if;
        end loop;
        if v('APP_ID') is not null then
            p_kind := 'APEX';
        elsif sys_context('userenv', 'session_user') = $$PLSQL_UNIT_OWNER then
            p_kind := 'COMMON';
        else
            p_kind := 'SCHEMA';
            p_value := sys_context('userenv', 'session_user');
        end if;
    end caller;

    -- the registered applications the caller acts for; null = no limit (COMMON itself, or unknown: an install
    -- outside an application)
    function caller_apps(p_kind in varchar2, p_value in varchar2) return apex_t_varchar2 is
        l_id   number;
        l_list apex_t_varchar2;
    begin
        if p_kind = 'COMMON' then
            return null;
        elsif p_kind = 'APEX' then
            l_id := to_number(v('APP_ID'));
            if l_id between 4000 and 4999 then
                l_id := to_number(v('FB_FLOW_ID'));    -- App Builder: the application being installed
            end if;
            if l_id is null then
                return null;
            end if;
            select application_code bulk collect into l_list from xxfnd_applications where apex_application_id = l_id;
        else
            select application_code bulk collect into l_list from xxfnd_applications
             where upper(schema_name) = upper(p_value);
        end if;
        if 'COMMON' member of l_list then
            return null;
        end if;
        return l_list;
    end caller_apps;

    function scope_predicate(p_change in boolean default false) return varchar2 is
        l_app  varchar2(30) := upper(v('G_ADMIN_APP'));
        l_del  varchar2(30);
        l_kind varchar2(10);
        l_val  varchar2(128);
        l_apps apex_t_varchar2;
    begin
        -- release 84: server code that has authorised its caller, or a background job (e.g. a workflow task action
        -- reading the notification wording), reads the setup of every application
        if xxfnd_vpd_pkg.is_trusted then
            return null;
        elsif not in_common then
            -- release 87: an application sees its own setup and the shared (instance) rows, never another
            -- application's; COMMON's own code (called by the application) reads every row
            caller(l_kind, l_val, true);
            l_apps := caller_apps(l_kind, l_val);
            if l_apps is null then
                return null;
            elsif l_apps.count = 0 then
                return 'application_code is null';
            end if;
            return 'application_code is null or application_code in (select column_value from table(apex_string.split('
                   || dbms_assert.enquote_literal(apex_string.join(l_apps, ':')) || ', '':'')))';
        elsif is_common_admin = 'Y' then
            if l_app is null or l_app = 'ALL' then
                return null;
            end if;
            return 'application_code is null or application_code = ' || dbms_assert.enquote_literal(l_app);
        end if;
        l_del := delegated_app;
        if l_del is null then
            return '1 = 0';
        elsif p_change then
            return 'application_code = ' || dbms_assert.enquote_literal(l_del);
        end if;
        return 'application_code is null or application_code = ' || dbms_assert.enquote_literal(l_del);
    end scope_predicate;

    function policy_read(p_schema in varchar2, p_object in varchar2) return varchar2 is
    begin
        return scope_predicate;
    end policy_read;

    function policy_change(p_schema in varchar2, p_object in varchar2) return varchar2 is
    begin
        return scope_predicate(true);
    end policy_change;

    function scoped_tables return apex_t_varchar2 is
    begin
        -- not XXFND_ROLES: the access checks read every role (the Roles screen filters by application itself)
        return apex_t_varchar2('XXFND_LOOKUP_TYPES', 'XXFND_NOTIFICATION_TEMPLATES',
                               'XXFND_INTEGRATION_PURPOSES', 'XXFND_DOCUMENT_ENTITIES',   -- release 86: endpoints retired
                               'XXFND_DOCUMENT_CATEGORIES', 'XXFND_ATTACHMENT_FUNCTIONS', 'XXFND_DF_FLEXFIELDS',
                               'XXFND_VALUE_SETS', 'XXFND_RETENTION_POLICIES', 'XXFND_STORAGE_CONFIG');
    end scoped_tables;

    function apex_app_id(p_application_code in varchar2) return number is
        l_id number;
    begin
        if upper(p_application_code) = 'ALL' then
            return null;   -- release 71: no single application chosen
        end if;
        select max(apex_application_id) into l_id from xxfnd_applications where application_code = upper(p_application_code);
        return coalesce(l_id, to_number(v('APP_ID')));
    end apex_app_id;

    function setup_page_url(p_page_id in number) return varchar2 is
        l_n    pls_integer;
        l_code xxfnd_applications.application_code%type;
    begin
        if p_page_id is null then
            return null;
        end if;
        select count(*) into l_n from apex_application_pages
         where application_id = to_number(v('APP_ID')) and page_id = p_page_id;
        if l_n > 0 then
            return apex_page.get_url(p_page => p_page_id);
        end if;
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS'));
        return apex_page.get_url(p_application => 'COMMON', p_page => 99,
                                 p_items  => 'G_ADMIN_APP,G_ADMIN_LOCK,P99_PAGE',
                                 p_values => nvl(l_code, upper(v('APP_ALIAS'))) || ',Y,' || to_char(p_page_id));
    end setup_page_url;

    function local_page(p_page_id in number) return varchar2 is
        l_n pls_integer;
    begin
        select count(*) into l_n from apex_application_pages
         where application_id = to_number(v('APP_ID')) and page_id = p_page_id;
        return case when l_n > 0 then 'Y' else 'N' end;
    end local_page;

    function is_delegated(p_application_code in varchar2, p_feature_code in varchar2,
                          p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        select count(*) into l_n
          from xxfnd_application_functions af
         where af.application_code = upper(p_application_code)
           and af.feature_code = upper(p_feature_code)
           and af.managed_in_app_flag = 'Y'
           and exists (select 1
                         from xxfnd_user_roles_v ur
                         join xxfnd_role_privileges rp on rp.role_code = ur.role_code
                         join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
                        where ur.user_name = l_user
                          and ur.active_flag = 'Y'
                          and ur.application_code = af.application_code
                          and p.feature_code = af.feature_code);
        return case when l_n > 0 then 'Y' else 'N' end;
    end is_delegated;

    function delegated_any(p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        select count(*) into l_n
          from xxfnd_application_functions af
         where af.managed_in_app_flag = 'Y'
           and exists (select 1
                         from xxfnd_user_roles_v ur
                         join xxfnd_role_privileges rp on rp.role_code = ur.role_code
                         join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
                        where ur.user_name = l_user
                          and ur.active_flag = 'Y'
                          and ur.application_code = af.application_code
                          and p.feature_code = af.feature_code)
           and rownum = 1;
        return case when l_n > 0 then 'Y' else 'N' end;
    end delegated_any;

    function delegated_app return varchar2 is
        l_app varchar2(30) := upper(v('G_ADMIN_APP'));
        l_n   pls_integer;
    begin
        if nvl(v('G_ADMIN_LOCK'), 'N') <> 'Y' or l_app is null or l_app = 'ALL' then
            return null;
        end if;
        select count(*) into l_n from xxfnd_application_functions
         where application_code = l_app and managed_in_app_flag = 'Y'
           and is_delegated(application_code, feature_code) = 'Y';
        return case when l_n > 0 then l_app end;
    end delegated_app;

    function page_allowed(p_page_id in number) return varchar2 is
        l_feature xxfnd_feature_pages.feature_code%type;
        l_app     varchar2(30);
    begin
        if not in_common or is_common_admin = 'Y' then
            return 'Y';
        end if;
        l_app := delegated_app;
        if l_app is null then
            return 'N';
        end if;
        select max(feature_code) into l_feature from xxfnd_feature_pages
         where app_alias = 'COMMON' and page_id = p_page_id;
        if l_feature is null then
            return case when p_page_id = 99 then 'Y' else 'N' end;   -- the entry page
        end if;
        return is_delegated(l_app, l_feature);
    end page_allowed;

    function delegated_url(p_feature_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type;
    begin
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS'));
        if l_code is null or is_delegated(l_code, p_feature_code) = 'N' then
            return null;
        end if;
        return menu_url(l_code, 'MANAGED', null, p_feature_code);
    end delegated_url;

    procedure submit_feedback(p_application_id in number, p_page_id in number, p_type in number, p_comment in varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from xxfnd_applications where apex_application_id = p_application_id;
        if l_n = 0 then
            raise_application_error(-20171, 'Feedback is taken for the registered applications only.');
        end if;
        if trim(p_comment) is null then
            raise_application_error(-20173, 'Enter your feedback.');
        end if;
        apex_util.submit_feedback(p_comment        => p_comment,
                                  p_type           => nvl(p_type, 1),
                                  p_application_id => p_application_id,
                                  p_page_id        => p_page_id);
    end submit_feedback;

    procedure feedback_follow_up(p_feedback_id in number, p_follow_up in varchar2) is
    begin
        if not xxfnd_privilege_pkg.has_privilege('USAGE_FEEDBACK', 'MANAGE') then
            raise_application_error(-20172, 'You are not allowed to follow up feedback (Usage and Feedback - Manage).');
        end if;
        apex_util.submit_feedback_followup(p_feedback_id => p_feedback_id, p_follow_up => p_follow_up);
    end feedback_follow_up;

    ----------------------------------------------------------------------------
    -- Release 86: onboarding and the registration rule
    ----------------------------------------------------------------------------
    -- in an APEX session the caller needs Applications - Manage; scripts (no APEX session) may
    procedure check_manage is
    begin
        if xxfnd_util_pkg.in_apex_session and not xxfnd_privilege_pkg.has_privilege('APPLICATIONS', 'MANAGE') then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        end if;
    end check_manage;

    function registered_code(p_application_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type;
    begin
        select max(application_code) into l_code from xxfnd_applications
         where application_code = upper(trim(p_application_code));
        if l_code is null then
            xxfnd_error_pkg.raise_error('XXFND_APP_NOT_REGISTERED',
                                        apex_t_varchar2(nvl(upper(trim(p_application_code)), '-')));
        end if;
        -- release 87: the caller changes only its own application's rows (golden rule): COMMON itself and IT (the COMMON
        -- application) may act for any application
        declare
            l_kind varchar2(10);
            l_val  varchar2(128);
            l_apps apex_t_varchar2;
        begin
            caller(l_kind, l_val, false);
            l_apps := caller_apps(l_kind, l_val);
            if l_apps is not null and not (l_code member of l_apps) then
                xxfnd_error_pkg.raise_error('XXFND_REG_WRONG_CALLER',
                    apex_t_varchar2(l_code, nvl(apex_string.join(l_apps, ', '), nvl(l_val, l_kind))));
            end if;
        end;
        return l_code;
    end registered_code;

    function setup_code(p_application_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        return case when l_code = 'COMMON' then null else l_code end;
    end setup_code;

    procedure assert_same_application(p_what in varchar2, p_key in varchar2, p_row_application in varchar2,
                                      p_application_code in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        if p_row_application is not null and upper(p_row_application) <> l_code then
            xxfnd_error_pkg.raise_error('XXFND_REG_OTHER_APP', apex_t_varchar2(p_what, p_key, upper(p_row_application)));
        end if;
    end assert_same_application;

    procedure remove_registered(p_application_code in varchar2,
                                p_what             in varchar2,
                                p_table            in varchar2,
                                p_key_columns      in apex_t_varchar2,
                                p_keys             in apex_t_varchar2,
                                p_owner_sql        in varchar2 default 't.application_code') is
        e_in_use exception;
        pragma exception_init(e_in_use, -2292);
        l_code  xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_where varchar2(4000);
        l_key   varchar2(4000) := apex_string.join(p_keys, ' / ');
        l_n     pls_integer;
        l_owner varchar2(255);
        procedure run(p_sql in varchar2, p_into in boolean) is
        begin
            case p_keys.count
                when 1 then
                    if p_into then execute immediate p_sql into l_n, l_owner using p_keys(1);
                    else execute immediate p_sql using p_keys(1); end if;
                when 2 then
                    if p_into then execute immediate p_sql into l_n, l_owner using p_keys(1), p_keys(2);
                    else execute immediate p_sql using p_keys(1), p_keys(2); end if;
                else
                    if p_into then execute immediate p_sql into l_n, l_owner using p_keys(1), p_keys(2), p_keys(3);
                    else execute immediate p_sql using p_keys(1), p_keys(2), p_keys(3); end if;
            end case;
        end run;
    begin
        for i in 1 .. p_key_columns.count loop
            l_where := l_where || case when i > 1 then ' and ' end
                    || 't.' || dbms_assert.simple_sql_name(p_key_columns(i)) || ' = :k' || i;
        end loop;
        -- every row is seen, whoever asks: the ownership check below decides
        xxfnd_vpd_pkg.begin_trusted;
        begin
            run('select count(*), max(nvl(' || p_owner_sql || ', ''COMMON'')) from '
                || dbms_assert.simple_sql_name(p_table) || ' t where ' || l_where, true);
            if l_n = 0 then
                xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2(p_what, l_key));
            elsif l_owner <> l_code then
                xxfnd_error_pkg.raise_error('XXFND_REG_OTHER_APP', apex_t_varchar2(p_what, l_key, l_owner));
            end if;
            run('delete from ' || dbms_assert.simple_sql_name(p_table) || ' t where ' || l_where, false);
        exception
            when e_in_use then
                xxfnd_vpd_pkg.end_trusted;
                xxfnd_error_pkg.raise_error('XXFND_REG_IN_USE', apex_t_varchar2(p_what, l_key));
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end remove_registered;

    procedure remove_all_registered(p_application_code in varchar2,
                                    p_what             in varchar2,
                                    p_table            in varchar2,
                                    p_owner_sql        in varchar2 default 't.application_code') is
        e_in_use exception;
        pragma exception_init(e_in_use, -2292);
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        if l_code = 'COMMON' then
            xxfnd_error_pkg.raise_error('XXFND_APP_DELETE_COMMON');
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            execute immediate 'delete from ' || dbms_assert.simple_sql_name(p_table) || ' t where ' || p_owner_sql || ' = :c'
                using l_code;
        exception
            when e_in_use then
                xxfnd_vpd_pkg.end_trusted;
                xxfnd_error_pkg.raise_error('XXFND_REG_IN_USE', apex_t_varchar2(p_what, l_code));
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end remove_all_registered;

    procedure unregister_menu_entry(p_application_code in varchar2, p_entry_code in varchar2) is
        l_made xxfnd_app_menu_entries.made_by%type;
    begin
        select max(made_by) into l_made from xxfnd_app_menu_entries
         where application_code = registered_code(p_application_code) and entry_code = upper(trim(p_entry_code));
        if l_made = 'COMMON' then
            xxfnd_error_pkg.raise_error('XXFND_REG_OTHER_APP',
                                        apex_t_varchar2('Menu entry', upper(trim(p_entry_code)), 'COMMON'));
        end if;
        remove_registered(p_application_code, 'Menu entry', 'XXFND_APP_MENU_ENTRIES',
                          apex_t_varchar2('APPLICATION_CODE', 'ENTRY_CODE'),
                          apex_t_varchar2(registered_code(p_application_code), upper(trim(p_entry_code))));
    end unregister_menu_entry;

    -- the workspace of the registered applications (COMMON's), else the running application's
    function workspace_name return varchar2 is
        l_ws varchar2(255);
    begin
        select max(x.workspace) into l_ws
          from apex_applications x
         where x.application_id = coalesce((select max(apex_application_id) from xxfnd_applications
                                             where application_code = 'COMMON'), to_number(v('APP_ID')));
        return l_ws;
    end workspace_name;

    procedure save_application(p_application_code    in varchar2,
                               p_apex_application_id in number,
                               p_description         in varchar2 default null,
                               p_enabled_flag        in varchar2 default 'Y',
                               p_email_enabled_flag  in varchar2 default 'Y') is
        l_code   xxfnd_applications.application_code%type := upper(trim(p_application_code));
        l_ws     varchar2(255) := workspace_name;
        l_name   varchar2(4000);
        l_alias  varchar2(4000);
        l_schema varchar2(4000);
        l_other  xxfnd_applications.application_code%type;
    begin
        check_manage;
        if l_code is null or not regexp_like(l_code, '^[A-Z][A-Z0-9_]{0,29}$') then
            xxfnd_error_pkg.raise_error('XXFND_APP_CODE_INVALID', apex_t_varchar2(nvl(l_code, '-')));
        end if;
        -- name, alias and parsing schema are those of the APEX application (one source of truth)
        select max(application_name), max(alias), max(owner) into l_name, l_alias, l_schema
          from apex_applications
         where application_id = p_apex_application_id
           and (l_ws is null or workspace = l_ws);
        if l_name is null then
            xxfnd_error_pkg.raise_error('XXFND_APP_APEX_NOT_FOUND', apex_t_varchar2(to_char(p_apex_application_id)));
        end if;
        select max(application_code) into l_other from xxfnd_applications
         where application_code <> l_code
           and (apex_application_id = p_apex_application_id or upper(apex_app_alias) = upper(l_alias));
        if l_other is not null then
            xxfnd_error_pkg.raise_error('XXFND_APP_APEX_TAKEN', apex_t_varchar2(to_char(p_apex_application_id), l_other));
        end if;
        merge into xxfnd_applications t
        using (select l_code application_code from dual) s
           on (t.application_code = s.application_code)
         when matched then update set t.application_name    = substr(l_name, 1, 240),
                                      t.apex_app_alias      = l_alias,
                                      t.apex_application_id = p_apex_application_id,
                                      t.schema_name         = l_schema,
                                      t.description         = p_description,
                                      t.enabled_flag        = case when l_code = 'COMMON' then 'Y'
                                                                   else nvl(p_enabled_flag, 'Y') end
         when not matched then insert (application_code, application_name, apex_app_alias, apex_application_id,
                                       schema_name, description, enabled_flag)
                               values (l_code, substr(l_name, 1, 240), l_alias, p_apex_application_id, l_schema,
                                       p_description, nvl(p_enabled_flag, 'Y'));
        -- the e-mail switch (column added after this package, 09e: written by name)
        execute immediate 'update xxfnd_applications set email_enabled_flag = :e where application_code = :c'
            using case when p_email_enabled_flag = 'N' then 'N' else 'Y' end, l_code;
        -- grants to its schema, its APEX ID and one row per common function (not managed in the application)
        register_application(l_code);
        -- its workflow processes and the RFI process (new rows on, existing rows kept); XXFND_WORKFLOW_PKG is
        -- installed later (15): called by name
        execute immediate 'begin xxfnd_workflow_pkg.sync_processes; end;';
    end save_application;

    procedure onboard(p_apex_application_id in number,
                      p_application_code    in varchar2,
                      p_description         in varchar2 default null,
                      p_email_enabled_flag  in varchar2 default 'Y',
                      p_admin_user          in varchar2 default null) is
        l_code    xxfnd_applications.application_code%type := upper(trim(p_application_code));
        l_app     xxfnd_applications%rowtype;
        l_before  apex_t_varchar2;
        l_new     apex_t_varchar2;
        l_role    xxfnd_roles.role_code%type;
        l_roles   pls_integer;
        l_created timestamp;
        l_email   varchar2(1);
        l_granted pls_integer;
    begin
        check_manage;
        -- XXFND_WORKFLOW_PROCESSES is created after this package (09e): read by name
        execute immediate 'select process_code from xxfnd_workflow_processes where application_code = :c'
            bulk collect into l_before using l_code;
        select count(*) into l_roles from xxfnd_applications where application_code = l_code;
        if l_roles > 0 then
            -- a re-run refreshes the registration and keeps what the administrators set
            select * into l_app from xxfnd_applications where application_code = l_code;
            execute immediate 'select email_enabled_flag from xxfnd_applications where application_code = :c'
                into l_email using l_code;
            save_application(l_code, p_apex_application_id, nvl(l_app.description, p_description),
                             l_app.enabled_flag, l_email);
        else
            save_application(l_code, p_apex_application_id, p_description, 'Y', nvl(p_email_enabled_flag, 'Y'));
        end if;
        select * into l_app from xxfnd_applications where application_code = l_code;

        -- the shared processes (not the application's own APEX workflows, e.g. RFI) start off; only rows made now
        execute immediate q'~select w.process_code from xxfnd_workflow_processes w
                   where w.application_code = :c
                     and w.process_code not in (select column_value from table(:b))
                     and not exists (select 1 from apex_appl_workflows x
                                      where x.application_id = :i and upper(x.static_id) = w.process_code)~'
            bulk collect into l_new using l_code, l_before, l_app.apex_application_id;
        for i in 1 .. l_new.count loop
            -- XXFND_WORKFLOW_PKG is installed later (15): called by name
            execute immediate 'begin xxfnd_workflow_pkg.set_process_enabled(:a, :p, ''N''); end;'
                using l_code, l_new(i);
        end loop;

        -- the application's administrator: every privilege of its features when the role is made; on a re-run only
        -- the privileges registered since the last onboarding (the role's LAST_UPDATE_DATE, set below), so what an
        -- administrator took away stays away
        l_role := substr(l_code, 1, 24) || '_ADMIN';
        select count(*) into l_roles from xxfnd_roles where role_code = l_role;
        xxfnd_privilege_pkg.register_role(l_code, l_role, substr(l_app.application_name, 1, 185) || ' Administrator',
                                          substr('Administers ' || l_app.application_name
                                                 || ': every feature of the application (onboarding).', 1, 500));
        select last_update_date into l_created from xxfnd_roles where role_code = l_role;
        l_granted := 0;
        for p in (select p.privilege_code from xxfnd_privileges p
                    join xxfnd_features f on f.feature_code = p.feature_code
                   where f.application_id = l_app.application_id
                     and (l_roles = 0 or p.creation_date > l_created)) loop
            xxfnd_privilege_pkg.add_role_privilege(l_code, l_role, p.privilege_code);
            l_granted := l_granted + 1;
        end loop;
        if l_granted > 0 and l_roles > 0 then
            -- the onboarding mark: the WHO trigger sets LAST_UPDATE_DATE
            update xxfnd_roles set role_name = role_name where role_code = l_role;
        end if;
        if trim(p_admin_user) is not null then
            -- XXFND_USER_PKG is installed later (16j): called by name; it gives the role outside an APEX session
            execute immediate 'begin xxfnd_user_pkg.bootstrap_admin(p_user_name => :u, p_role_code => :r); end;'
                using upper(trim(p_admin_user)), l_role;
        end if;
        ensure_menu(l_code);    -- release 87: the application's menu for the common functions
    end onboard;

    procedure set_enabled(p_application_code in varchar2, p_enabled_flag in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        check_manage;
        if l_code = 'COMMON' and nvl(p_enabled_flag, 'N') <> 'Y' then
            xxfnd_error_pkg.raise_error('XXFND_APP_COMMON_ALWAYS');
        end if;
        update xxfnd_applications set enabled_flag = case when p_enabled_flag = 'Y' then 'Y' else 'N' end
         where application_code = l_code
           and enabled_flag <> case when p_enabled_flag = 'Y' then 'Y' else 'N' end;
    end set_enabled;

    function delete_blocker(p_application_code in varchar2) return varchar2 is
        l_app  xxfnd_applications%rowtype;
        l_list varchar2(4000);
        l_n    number;
        procedure found(p_what in varchar2, p_count in number) is
        begin
            if p_count > 0 then
                l_list := substr(l_list || case when l_list is not null then ', ' end || p_what || ': ' || p_count, 1, 3000);
            end if;
        end found;
    begin
        select * into l_app from xxfnd_applications where application_code = registered_code(p_application_code);
        if l_app.application_code = 'COMMON' then
            return xxfnd_error_pkg.message('XXFND_APP_DELETE_COMMON');
        elsif l_app.enabled_flag = 'Y' then
            return xxfnd_error_pkg.message('XXFND_APP_DELETE_ENABLED', apex_t_varchar2(l_app.application_code));
        end if;
        -- every row is counted, whoever asks (data security and the administration scope do not hide any)
        xxfnd_vpd_pkg.begin_trusted;
        begin
            -- any table of the platform that keeps an application code: RFIs, communications, notifications ...
            -- release 88 (C9): business data only - the application's own standard rows and the setup it registered
            -- (removed by DELETE_APPLICATION through each component's UNREGISTER_APPLICATION) do not block
            for t in (select c.table_name from user_tab_columns c
                        join user_tables u on u.table_name = c.table_name
                       where c.column_name = 'APPLICATION_CODE'
                         and (c.table_name like 'XXFND\_%' escape '\' or c.table_name like 'XXHR\_%' escape '\')
                         and c.table_name not in ('XXFND_APPLICATIONS', 'XXFND_APPLICATION_FUNCTIONS',
                                                  'XXFND_WORKFLOW_PROCESSES', 'XXFND_SETUP_TYPE_APPS', 'XXFND_ROLES',
                                                  'XXFND_APP_MENU_ENTRIES', 'XXFND_LOOKUP_TYPES', 'XXFND_APPROVAL_TYPES',
                                                  'XXFND_ATTACHMENT_FUNCTIONS', 'XXFND_DF_FLEXFIELDS', 'XXFND_VALUE_SETS',
                                                  'XXFND_DOCUMENT_CATEGORIES', 'XXFND_DOCUMENT_ENTITIES',
                                                  'XXFND_INTEGRATION_PURPOSES', 'XXFND_NOTIFICATION_TEMPLATES',
                                                  'XXFND_NOTIFY_RULES', 'XXFND_STORAGE_CONFIG', 'XXFND_CONTACT_SOURCES',
                                                  'XXFND_DM_APP_SCOPES', 'XXFND_DM_TABLE_GROUPS',
                                                  -- release 96: security model rows (removed with the application)
                                                  'XXFND_USER_APPLICATIONS', 'XXFND_DATA_OBJECTS',
                                                  'XXFND_DATA_DIMENSIONS', 'XXHR_ORGANIZATIONS')
                       order by c.table_name) loop
                execute immediate 'select count(*) from ' || dbms_assert.simple_sql_name(t.table_name)
                               || ' where application_code = :c' into l_n using l_app.application_code;
                found(initcap(replace(regexp_replace(t.table_name, '^XX[A-Z]+_'), '_', ' ')), l_n);
            end loop;
            -- documents of the application's records (its registered entities)
            select count(*) into l_n from xxfnd_attached_documents ad
              join xxfnd_document_entities e on e.entity_name = ad.entity_name
             where e.application_code = l_app.application_code;
            found('Documents', l_n);
            -- roles in use: named by segregation of duties, deadlines or another application's approvals (release 88:
            -- the roles' users, its own data rules and approval rules go with it); the deadline and approval
            -- tables are created after this package (15, 15d): read by name
            execute immediate q'~select count(*) from xxfnd_roles r
             where r.application_code = :c
               and (exists (select 1 from xxfnd_sod_rules x where r.role_code in (x.role_code_1, x.role_code_2))
                    or exists (select 1 from xxfnd_task_settings x where x.escalation_role_code = r.role_code)
                    or exists (select 1 from xxfnd_approval_rule_steps x
                                 join xxfnd_approval_rules ar on ar.rule_id = x.rule_id
                                 join xxfnd_approval_types y on y.approval_type_code = ar.approval_type_code
                                where x.role_code = r.role_code and nvl(y.application_code, '#') <> :c))~'
                into l_n using l_app.application_code, l_app.application_code;
            found('Roles in use', l_n);
            -- its APEX tasks and workflows
            select count(*) into l_n from apex_tasks where application_id = l_app.apex_application_id;
            found('Tasks', l_n);
            select count(*) into l_n from apex_workflows where application_id = l_app.apex_application_id;
            found('Workflows', l_n);
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        if l_list is not null then
            return xxfnd_error_pkg.message('XXFND_APP_DELETE_DATA', apex_t_varchar2(l_app.application_code, l_list));
        end if;
        return null;
    end delete_blocker;

    procedure delete_application(p_application_code in varchar2) is
        l_code   xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_reason varchar2(4000);
    begin
        check_manage;
        l_reason := delete_blocker(l_code);
        if l_reason is not null then
            xxfnd_error_pkg.raise_error('XXFND_APP_DELETE_BLOCKED', apex_t_varchar2(l_reason));
        end if;
        -- release 88 (C9): the setup it registered goes first, each component removing its own rows (created after
        -- this package: called by name); a row still used by business data stops the delete (ORA-20196)
        for c in (select column_value pkg from table(apex_t_varchar2(
                      'XXFND_APPROVAL_RULE_PKG', 'XXFND_NOTIFY_PKG', 'XXFND_WORKFLOW_PKG', 'XXFND_INTEGRATION_PKG',
                      'XXFND_ATTACH_PKG', 'XXFND_DFF_PKG', 'XXFND_LOOKUP_PKG', 'XXFND_PRIVILEGE_PKG',
                      'XXFND_DATA_MODEL_PKG', 'XXFND_VPD_PKG'))) loop
            execute immediate 'begin ' || dbms_assert.simple_sql_name(c.pkg) || '.unregister_application(:c); end;'
                using l_code;
        end loop;
        -- its own standard rows (made when it was registered) go with it; unused roles take their privileges along
        delete from xxfnd_application_functions where application_code = l_code;
        -- XXFND_WORKFLOW_PROCESSES is created after this package (09e): by name
        execute immediate 'delete from xxfnd_workflow_processes where application_code = :c' using l_code;
        delete from xxfnd_setup_type_apps where application_code = l_code;
        delete from xxfnd_roles where application_code = l_code;
        delete from xxfnd_applications where application_code = l_code;
    end delete_application;

    procedure save_functions(p_application_code in varchar2, p_managed_features in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_list apex_t_varchar2 := apex_string.split(upper(p_managed_features), ':');
    begin
        check_manage;
        ensure_rows(l_code);
        update xxfnd_application_functions f
           set f.managed_in_app_flag = case when f.feature_code in (select column_value from table(l_list)) then 'Y' else 'N' end
         where f.application_code = l_code
           and f.managed_in_app_flag <> case when f.feature_code in (select column_value from table(l_list)) then 'Y' else 'N' end;
        ensure_menu(l_code);
    end save_functions;

    procedure ensure_menu(p_application_code in varchar2) is
        l_code xxfnd_applications.application_code%type := upper(p_application_code);
        procedure entry(p_entry in varchar2, p_label in varchar2, p_type in varchar2, p_page in number,
                        p_feature in varchar2, p_icon in varchar2, p_seq in number) is
        begin
            insert into xxfnd_app_menu_entries (application_code, entry_code, label, display_sequence, icon_css,
                                                target_type, page_id, feature_code, made_by)
            select l_code, p_entry, p_label, p_seq, p_icon, p_type, p_page, p_feature, 'COMMON' from dual
             where not exists (select 1 from xxfnd_app_menu_entries
                                where application_code = l_code and entry_code = p_entry);
        end entry;
    begin
        if l_code = 'COMMON' then
            return;     -- COMMON has its own navigation
        end if;
        entry('MY_TASKS',      'My Tasks',      'COMMON_PAGE',  40,   null, 'fa-inbox',      10);
        entry('NOTIFICATIONS', 'Notifications', 'COMMON_PAGE',  43,   null, 'fa-bell-o',     20);
        entry('SHARED_SETUP',  'Shared Setup',  'SHARED_SETUP', null, null, 'fa-cogs',       80);
        entry('GIVE_FEEDBACK', 'Feedback',      'COMMON_PAGE',  173,  null, 'fa-comment-o',  90);
        -- one entry per common function: shown when IT lets the application manage it (MENU_VISIBLE)
        for f in (select f.feature_code, f.feature_name, f.icon_css, f.display_sequence
                    from xxfnd_features f
                   where f.feature_code in (select column_value from table(common_functions))) loop
            entry('FN_' || f.feature_code, f.feature_name, 'MANAGED', null, f.feature_code,
                  nvl(f.icon_css, 'fa-cog'), 100 + nvl(f.display_sequence, 0));
        end loop;
    end ensure_menu;

    procedure register_menu_entry(p_application_code in varchar2,
                                  p_entry_code       in varchar2,
                                  p_label            in varchar2,
                                  p_target_type      in varchar2,
                                  p_page_id          in number   default null,
                                  p_feature_code     in varchar2 default null,
                                  p_icon_css         in varchar2 default null,
                                  p_display_sequence in number   default null,
                                  p_parent_code      in varchar2 default null) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        if upper(p_target_type) not in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE', 'MANAGED', 'SHARED_SETUP', 'FOLDER')
           or (upper(p_target_type) in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE') and p_page_id is null) then
            xxfnd_error_pkg.raise_error('XXFND_MENU_TARGET', apex_t_varchar2(p_entry_code));
        end if;
        insert into xxfnd_app_menu_entries (application_code, entry_code, label, parent_code, display_sequence, icon_css,
                                            target_type, page_id, feature_code, made_by)
        select l_code, upper(trim(p_entry_code)), p_label, upper(p_parent_code), nvl(p_display_sequence, 100), p_icon_css,
               upper(p_target_type), p_page_id, upper(p_feature_code), 'APP'
          from dual
         where not exists (select 1 from xxfnd_app_menu_entries
                            where application_code = l_code and entry_code = upper(trim(p_entry_code)));
    end register_menu_entry;

    procedure save_menu_entry(p_application_code in varchar2,
                              p_entry_code       in varchar2,
                              p_label            in varchar2,
                              p_display_sequence in number,
                              p_icon_css         in varchar2,
                              p_enabled_flag     in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        check_manage;
        update xxfnd_app_menu_entries
           set label = nvl(p_label, label), display_sequence = nvl(p_display_sequence, display_sequence),
               icon_css = nvl(p_icon_css, icon_css),
               enabled_flag = case when p_enabled_flag = 'N' then 'N' else 'Y' end
         where application_code = l_code and entry_code = upper(p_entry_code);
    end save_menu_entry;

    procedure maintain_menu_entry(p_application_code in varchar2,
                                  p_entry_code       in varchar2,
                                  p_label            in varchar2,
                                  p_parent_code      in varchar2,
                                  p_display_sequence in number,
                                  p_icon_css         in varchar2,
                                  p_target_type      in varchar2,
                                  p_page_id          in number,
                                  p_feature_code     in varchar2,
                                  p_enabled_flag     in varchar2) is
        l_code   xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_entry  xxfnd_app_menu_entries.entry_code%type   := upper(trim(p_entry_code));
        l_type   xxfnd_app_menu_entries.target_type%type  := upper(p_target_type);
        l_parent xxfnd_app_menu_entries.parent_code%type  := upper(trim(p_parent_code));
        l_page   number := case when l_type in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE') then p_page_id end;
        l_n      pls_integer;
    begin
        check_manage;
        if l_entry is null or trim(p_label) is null
           or l_type not in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE', 'MANAGED', 'SHARED_SETUP', 'FOLDER')
           or (l_type in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE') and l_page is null)
           or (l_type = 'MANAGED' and p_feature_code is null) then
            xxfnd_error_pkg.raise_error('XXFND_MENU_TARGET', apex_t_varchar2(nvl(l_entry, '-')));
        end if;
        -- the parent: a folder of the application, not the entry itself and not an entry inside it
        if l_parent is not null then
            select count(*) into l_n from xxfnd_app_menu_entries
             where application_code = l_code and entry_code = l_parent and target_type = 'FOLDER'
               and l_parent not in (select entry_code from xxfnd_app_menu_entries
                                     where application_code = l_code
                                     start with entry_code = l_entry and application_code = l_code
                                     connect by prior entry_code = parent_code and application_code = l_code);
            if l_n = 0 then
                xxfnd_error_pkg.raise_error('XXFND_MENU_PARENT', apex_t_varchar2(l_entry));
            end if;
        end if;
        merge into xxfnd_app_menu_entries t
        using (select l_code application_code, l_entry entry_code from dual) s
           on (t.application_code = s.application_code and t.entry_code = s.entry_code)
         when matched then update set t.label = trim(p_label), t.parent_code = l_parent,
              t.display_sequence = nvl(p_display_sequence, t.display_sequence), t.icon_css = p_icon_css,
              t.target_type = l_type, t.page_id = l_page, t.feature_code = upper(p_feature_code),
              t.enabled_flag = case when p_enabled_flag = 'N' then 'N' else 'Y' end
         when not matched then insert (application_code, entry_code, label, parent_code, display_sequence, icon_css,
                                       target_type, page_id, feature_code, enabled_flag, made_by)
              values (l_code, l_entry, trim(p_label), l_parent, nvl(p_display_sequence, 100), p_icon_css, l_type, l_page,
                      upper(p_feature_code), case when p_enabled_flag = 'N' then 'N' else 'Y' end, 'ADMIN');
    end maintain_menu_entry;

    procedure delete_menu_entry(p_application_code in varchar2, p_entry_code in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_by   xxfnd_app_menu_entries.made_by%type;
    begin
        check_manage;
        select max(made_by) into l_by from xxfnd_app_menu_entries
         where application_code = l_code and entry_code = upper(p_entry_code);
        if l_by is null then
            return;
        elsif l_by <> 'ADMIN' then
            xxfnd_error_pkg.raise_error('XXFND_MENU_DELETE', apex_t_varchar2(upper(p_entry_code)));
        end if;
        -- the entry with the entries inside it (only entries an administrator added)
        delete from xxfnd_app_menu_entries
         where application_code = l_code
           and entry_code in (select entry_code from xxfnd_app_menu_entries
                               where application_code = l_code
                               start with entry_code = upper(p_entry_code) and application_code = l_code
                               connect by prior entry_code = parent_code and application_code = l_code)
           and made_by = 'ADMIN';
        -- an entry of COMMON or the application inside it moves up to the top level
        update xxfnd_app_menu_entries set parent_code = null
         where application_code = l_code
           and parent_code is not null
           and parent_code not in (select entry_code from xxfnd_app_menu_entries where application_code = l_code);
    end delete_menu_entry;

    function entry_visible(p_application_code in varchar2, p_target_type in varchar2, p_page_id in number,
                           p_feature_code in varchar2, p_enabled_flag in varchar2) return varchar2 is
        l_alias   xxfnd_applications.apex_app_alias%type;
        l_feature xxfnd_feature_pages.feature_code%type;
    begin
        if p_enabled_flag <> 'Y' then
            return 'N';
        elsif p_target_type = 'FOLDER' then
            return 'Y';      -- shown when one of its entries is shown (XXFND_NAV_MENU_V)
        elsif p_target_type = 'ADMIN_PAGE' and p_feature_code is null then
            -- the application's administration (e.g. its Administration page): an administrator of anything
            return case when xxfnd_privilege_pkg.has_any_admin_privilege then 'Y' else 'N' end;
        elsif p_target_type in ('MANAGED', 'SHARED_SETUP') or p_feature_code is not null
              or p_target_type not in ('APP_PAGE', 'ADMIN_PAGE') then
            return menu_visible(p_application_code, p_target_type, p_feature_code, p_enabled_flag);
        end if;
        -- a page of the application: the privilege of the feature the page belongs to, as on the page itself
        select max(apex_app_alias) into l_alias from xxfnd_applications where application_code = upper(p_application_code);
        select max(feature_code) into l_feature
          from xxfnd_feature_pages where upper(app_alias) = upper(l_alias) and page_id = p_page_id;
        if l_feature is null then
            return 'Y';      -- a page of no feature (e.g. the home page): every signed-in user
        end if;
        return xxfnd_privilege_pkg.has_privilege_yn(l_feature, 'VIEW');
    end entry_visible;

    function menu_visible(p_application_code in varchar2, p_target_type in varchar2, p_feature_code in varchar2,
                          p_enabled_flag in varchar2) return varchar2 is
    begin
        if p_enabled_flag <> 'Y' then
            return 'N';
        elsif p_target_type = 'MANAGED' then
            return is_delegated(p_application_code, p_feature_code);
        elsif p_target_type = 'SHARED_SETUP' then
            return case when xxfnd_privilege_pkg.has_any_admin_privilege then 'Y' else 'N' end;
        elsif p_feature_code is null then
            return 'Y';      -- every signed-in user (what each COMMON page shows is limited to the user's own data)
        end if;
        return xxfnd_privilege_pkg.has_privilege_yn(p_feature_code, 'VIEW');
    end menu_visible;

    function menu_url(p_application_code in varchar2, p_target_type in varchar2, p_page_id in number,
                      p_feature_code in varchar2) return varchar2 is
        l_home  number;
        l_alias xxfnd_applications.apex_app_alias%type;
    begin
        if p_target_type in ('APP_PAGE', 'ADMIN_PAGE') then
            -- release 104: the application's own page, also when its menu is shown in COMMON
            select max(apex_app_alias) into l_alias from xxfnd_applications
             where application_code = upper(p_application_code);
            return apex_page.get_url(p_application => l_alias, p_page => p_page_id);
        elsif p_target_type = 'FOLDER' then
            return null;     -- release 104: a folder opens its entries
        elsif p_target_type = 'SHARED_SETUP' then
            return apex_page.get_url(p_application => 'COMMON', p_page => 100);
        elsif p_target_type = 'MANAGED' then
            select max(home_page_id) into l_home from xxfnd_features where feature_code = upper(p_feature_code);
            return apex_page.get_url(p_application => 'COMMON', p_page => 99,
                                     p_items  => 'G_ADMIN_APP,G_ADMIN_LOCK,P99_PAGE',
                                     p_values => upper(p_application_code) || ',Y,' || to_char(l_home));
        elsif p_page_id = 173 then
            -- Give Feedback: on the page the user is on
            return apex_page.get_url(p_application => 'COMMON', p_page => 173,
                                     p_items  => 'P173_APPLICATION_ID,P173_PAGE_ID',
                                     p_values => v('APP_ID') || ',' || v('APP_PAGE_ID'));
        end if;
        return apex_page.get_url(p_application => 'COMMON', p_page => p_page_id);
    end menu_url;

end xxfnd_application_pkg;
/
