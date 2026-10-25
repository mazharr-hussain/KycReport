
--------------------------------------------------------------------------------
-- Privilege API
--------------------------------------------------------------------------------
create or replace package xxfnd_privilege_pkg authid definer as
    -- Current (or given) user holds FEATURE.ACTION through an active role.
    function has_privilege(p_feature_code in varchar2, p_action in varchar2,
                           p_user_name in varchar2 default null) return boolean;
    function has_privilege_yn(p_feature_code in varchar2, p_action in varchar2,
                              p_user_name in varchar2 default null) return varchar2;
    -- Privilege on the feature an APEX page belongs to. Unmapped page = no access.
    function has_page_privilege(p_page_id in number, p_action in varchar2,
                                p_app_alias in varchar2 default null) return boolean;
    -- For DML processes: request CREATE needs CREATE, any other request needs MANAGE.
    function has_page_request_privilege(p_page_id in number, p_request in varchar2,
                                        p_app_alias in varchar2 default null) return boolean;
    -- True when the user holds at least one privilege (application-level check).
    function has_any_privilege(p_user_name in varchar2 default null) return boolean;
    -- True when the user holds a privilege on any admin feature (Admin Console).
    function has_any_admin_privilege(p_user_name in varchar2 default null) return boolean;
    -- release 47: the running application (XXFND_APPLICATIONS) found by its APEX alias, else by its APEX ID;
    -- null outside APEX.
    function current_application_id return number;
    -- Records the APEX ID of the running application in this environment (called at sign-in).
    procedure sync_current_application;
    -- Colon-separated privilege codes of a role (shuttle value on the Role screen).
    function role_privilege_list(p_role_code in varchar2) return varchar2;
    -- Makes the role hold exactly the given privileges (colon-separated).
    procedure set_role_privileges(p_role_code in varchar2, p_privilege_list in varchar2);
    -- release 79 (from XXFND_SECURITY_PKG): roles and segregation of duties
    function has_role(p_role_code in varchar2, p_user_name in varchar2 default null) return boolean;
    function has_role_yn(p_role_code in varchar2, p_user_name in varchar2 default null) return varchar2;
    -- Comma-separated role codes; true when the user holds any of them.
    function has_any_role(p_role_codes in varchar2, p_user_name in varchar2 default null) return boolean;
    -- Y/N form of HAS_ANY_ROLE for use in SQL (report where clauses, LOVs).
    function has_any_role_yn(p_role_codes in varchar2, p_user_name in varchar2 default null) return varchar2;
    -- True when one of the user's roles may see sensitive data (XXFND_ROLES.VIEW_SENSITIVE_FLAG).
    function can_view_sensitive(p_user_name in varchar2 default null) return boolean;
    -- Four-eyes: true when acting under p_role_code would combine, on the same record, with a role the user
    -- already acted under there (p_prior_roles, SAME_RECORD rules), or when the user permanently holds a
    -- GLOBAL-conflicting role.
    function sod_conflict(p_role_code   in varchar2,
                          p_prior_roles in apex_t_varchar2 default null,
                          p_user_name   in varchar2 default null) return boolean;

    ----------------------------------------------------------------------------
    -- Release 86: registration by an application (its install script or COMMON's onboarding). Each adds the row only
    -- when it is missing and never changes what an administrator changed; a re-run does nothing. The application
    -- must be registered (XXFND_APP_NOT_REGISTERED, ORA-20180); a row of another application is refused
    -- (ORA-20186). No APEX session needed.
    ----------------------------------------------------------------------------
    procedure register_feature(p_application_code in varchar2,
                               p_feature_code     in varchar2,
                               p_feature_name     in varchar2,
                               p_feature_group    in varchar2 default 'BUSINESS',
                               p_display_sequence in number   default 100,
                               p_admin_flag       in varchar2 default 'N',
                               p_home_page_id     in number   default null,
                               p_icon_css         in varchar2 default null,
                               p_description      in varchar2 default null);
    -- A page of the application belongs to a feature (the application's APEX alias; ORA-20187 for an unknown feature).
    procedure register_feature_page(p_application_code in varchar2,
                                    p_feature_code     in varchar2,
                                    p_page_id          in number,
                                    p_tab_label        in varchar2 default null,
                                    p_tab_sequence     in number   default null);
    -- FEATURE.ACTION (VIEW, CREATE or MANAGE) of one of the application's features.
    procedure register_privilege(p_application_code in varchar2,
                                 p_feature_code     in varchar2,
                                 p_action_code      in varchar2,
                                 p_privilege_name   in varchar2 default null);
    -- Release 86: the privileges every role holds (each user works his own tasks, sends the e-mails and sees the
    -- documents of the records he may see, gives feedback): given to a new role (trigger XXFND_ROLES_EVERY_ROLE, 28),
    -- only those that exist; nothing else is changed.
    procedure give_every_role_privileges(p_role_code in varchar2);
    procedure register_role(p_application_code    in varchar2,
                            p_role_code           in varchar2,
                            p_role_name           in varchar2,
                            p_description         in varchar2 default null,
                            p_view_sensitive_flag in varchar2 default 'N');
    -- Gives one privilege (any application's, e.g. COMMON's DOCUMENTS.VIEW) to a role of the application. Additive:
    -- the role's other privileges stay (SET_ROLE_PRIVILEGES replaces them all).
    procedure add_role_privilege(p_application_code in varchar2, p_role_code in varchar2, p_privilege_code in varchar2);
    -- Two roles one person may not combine (stored in canonical order; scope SAME_RECORD or GLOBAL); at least one
    -- of them is the application's.
    procedure register_sod_rule(p_application_code in varchar2,
                                p_role_code_1      in varchar2,
                                p_role_code_2      in varchar2,
                                p_conflict_scope   in varchar2 default 'SAME_RECORD',
                                p_description      in varchar2 default null);
    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    -- C8: a page of the application no longer mapped to a feature
    procedure unregister_feature_page(p_application_code in varchar2, p_page_id in number);
    procedure unregister_privilege(p_application_code in varchar2, p_privilege_code in varchar2);
    -- the feature with its privileges and pages (refused while a role holds one of its privileges: in use)
    procedure unregister_feature(p_application_code in varchar2, p_feature_code in varchar2);
    -- a role given to nobody (its privileges and data rules go with it)
    procedure unregister_role(p_application_code in varchar2, p_role_code in varchar2);
    -- the pages, privileges and features of the application (its roles are deleted with the application)
    procedure unregister_application(p_application_code in varchar2);

    -- Release 96: roles inside roles. P_MEMBER_ROLE_CODE (a role of the same application or a COMMON role) becomes
    -- part of P_ROLE_CODE (a role of P_APPLICATION_CODE); a loop is refused (ORA-20076). The caller administers the
    -- application (XXFND_APPLICATION_PKG.CAN_ADMINISTER; ORA-20077 otherwise).
    procedure add_role_member(p_application_code in varchar2, p_role_code in varchar2, p_member_role_code in varchar2);
    procedure remove_role_member(p_application_code in varchar2, p_role_code in varchar2, p_member_role_code in varchar2);
    -- Y when the user may change the security rows of the application (COMMON administrator: every application).
    function can_change(p_application_code in varchar2) return varchar2;
end xxfnd_privilege_pkg;
/
