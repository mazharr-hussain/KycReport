
create or replace package xxfnd_application_pkg authid definer as

    ----------------------------------------------------------------------------
    -- Applications and their common functions (was XXFND_APP_FUNCTION_PKG)
    ----------------------------------------------------------------------------
    -- release 73: Y when IT lets the application's administrators maintain the common function's setup for their
    -- application (from the application's menu), else N.
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
    -- DBMS_RLS policy functions (policy XXFND_ADMIN_SCOPE on the setup tables with APPLICATION_CODE). Inside the
    -- COMMON application: a Common Administrator every row (G_ADMIN_APP = ALL) or one application's rows and the
    -- shared rows; release 106: anyone else the rows of the applications whose roles give the page's privilege
    -- (FEATURE_APPS) and the shared rows. Another application: its own rows and the shared rows.
    function policy_read(p_schema in varchar2, p_object in varchar2) return varchar2;
    function policy_change(p_schema in varchar2, p_object in varchar2) return varchar2;
    -- The setup tables scoped by application (policies and the default-application trigger).
    function scoped_tables return apex_t_varchar2;
    -- APEX application ID of an application (code; recorded at its sign-in), else the running application.
    function apex_app_id(p_application_code in varchar2) return number;
    -- release 68: link to a setup page from a business application - the page in the running application when it
    -- has it, otherwise the page in COMMON. Release 106: the COMMON page itself (no entry page 99): opened from the
    -- application, it works for that application (G_WORK_APP, process SET_ADMIN_APP).
    function setup_page_url(p_page_id in number) return varchar2;
    -- release 72: Y when the running application has the page (menus show only an application's own pages).
    function local_page(p_page_id in number) return varchar2;
    -- Release 106: access to a COMMON page is the privilege a role gives (any application; no "managed in the
    -- application" any more). The applications whose active roles (assigned, with the roles inside them) give the user
    -- a privilege on the feature - COMMON for a COMMON role (the shared rows); P_FEATURE_CODE null: the feature of the
    -- running COMMON page, else any admin feature. What a COMMON setup screen shows and changes (SCOPE_PREDICATE).
    function feature_apps(p_feature_code in varchar2 default null, p_user_name in varchar2 default null)
        return apex_t_varchar2;
    -- Release 106: retired with "managed in the application" - always N. Kept only for the copies of COMMON's
    -- Administration list subscribed before release 106 (they call it until the application refreshes them).
    function is_delegated(p_application_code in varchar2, p_feature_code in varchar2,
                          p_user_name in varchar2 default null) return varchar2;

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

    ----------------------------------------------------------------------------
    -- Release 87: the menu of an application for the common functions
    ----------------------------------------------------------------------------
    -- The default entries of an application (My Tasks, Notifications, Feedback, Shared Setup); only what is missing,
    -- so what IT changed is kept. Called by ONBOARD. Release 106: no entry per common function any more - any COMMON
    -- page is added to an application's menu on the Application Menu screen and shown by its privilege.
    procedure ensure_menu(p_application_code in varchar2);
    -- An application's own entry (made from its install): added when missing, never changed afterwards.
    -- P_TARGET_TYPE: COMMON_PAGE, APP_PAGE, ADMIN_PAGE, SHARED_SETUP, FOLDER, USER_MENU, SIGN_OUT or SEPARATOR
    -- (release 106: MANAGED retired); P_FEATURE_CODE: whose VIEW privilege shows it (empty = the page's privilege). The caller must be the application (REGISTERED_CODE).
    procedure register_menu_entry(p_application_code in varchar2,
                                  p_entry_code       in varchar2,
                                  p_label            in varchar2,
                                  p_target_type      in varchar2,
                                  p_page_id          in number   default null,
                                  p_feature_code     in varchar2 default null,
                                  p_icon_css         in varchar2 default null,
                                  p_display_sequence in number   default null,
                                  p_parent_code      in varchar2 default null,
                                  p_menu_code        in varchar2 default 'SIDE');
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
    -- SHARED_SETUP (release 106: MANAGED retired - a COMMON page is shown by its own privilege). MAINTAIN_MENU_ENTRY adds an entry (made by ADMIN) or changes one (any
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
                                  p_enabled_flag     in varchar2,
                                  p_menu_code        in varchar2 default 'SIDE');
    procedure delete_menu_entry(p_application_code in varchar2, p_entry_code in varchar2);
    -- Release 105: one place for every application's navigation, COMMON's too - the menu of an entry (MENU_CODE):
    -- SIDE (the navigation menu), TOP_BAR (the navigation bar: e.g. Notifications, Feedback, the user menu with
    -- USER_MENU, SEPARATOR, SIGN_OUT) or ADMIN (the Administration page). SYNC_MENU adds the entries an application is
    -- missing (COMMON: Home, My Tasks, a folder per module, an entry per screen, its top bar); nothing is changed or
    -- removed. Run by COMMON's install (script 31c) after every upgrade.
    procedure sync_menu(p_application_code in varchar2);
    -- Release 104: Y when the signed-in user sees the entry - the same privileges as the pages: the entry's feature
    -- (View), else for an application page the feature the page belongs to (View; a page of no feature: every user),
    -- a folder when one of its entries is seen (XXFND_NAV_MENU_V).
    function entry_visible(p_application_code in varchar2, p_target_type in varchar2, p_page_id in number,
                           p_feature_code in varchar2, p_enabled_flag in varchar2) return varchar2;
    -- For XXFND_APP_MENU_V: Y when the signed-in user sees the entry; the link of the entry.
    function menu_visible(p_application_code in varchar2, p_target_type in varchar2, p_feature_code in varchar2,
                          p_enabled_flag in varchar2) return varchar2;
    -- Release 111: a folder (menu group) opens its group page (COMMON page 100, P100_GROUP = P_ENTRY_CODE).
    function menu_url(p_application_code in varchar2, p_target_type in varchar2, p_page_id in number,
                      p_feature_code in varchar2, p_entry_code in varchar2 default null) return varchar2;
end xxfnd_application_pkg;
/
