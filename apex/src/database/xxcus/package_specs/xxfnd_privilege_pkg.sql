create or replace package xxcus.xxfnd_privilege_pkg authid definer as
    -- Current (or given) user holds FEATURE.ACTION through an active role.
    function has_privilege (
        p_feature_code in varchar2,
        p_action       in varchar2,
        p_user_name    in varchar2 default null
    ) return boolean;

    function has_privilege_yn (
        p_feature_code in varchar2,
        p_action       in varchar2,
        p_user_name    in varchar2 default null
    ) return varchar2;
    -- Privilege on the feature an APEX page belongs to. Unmapped page = no access.
    function has_page_privilege (
        p_page_id   in number,
        p_action    in varchar2,
        p_app_alias in varchar2 default null
    ) return boolean;
    -- For DML processes: request CREATE needs CREATE, any other request needs MANAGE.
    function has_page_request_privilege (
        p_page_id   in number,
        p_request   in varchar2,
        p_app_alias in varchar2 default null
    ) return boolean;
    -- True when the user holds at least one privilege (application-level check).
    function has_any_privilege (
        p_user_name in varchar2 default null
    ) return boolean;
    -- True when the user holds a privilege on any admin feature (Admin Console).
    function has_any_admin_privilege (
        p_user_name in varchar2 default null
    ) return boolean;
    -- Colon-separated privilege codes of a role (shuttle value on the Role screen).
    function role_privilege_list (
        p_role_code in varchar2
    ) return varchar2;
    -- Makes the role hold exactly the given privileges (colon-separated).
    procedure set_role_privileges (
        p_role_code      in varchar2,
        p_privilege_list in varchar2
    );

end xxfnd_privilege_pkg;
/


-- sqlcl_snapshot {"hash":"4b0eac1a6cfa167bc4bb2f1870572f6bf73788ed","type":"PACKAGE_SPEC","name":"XXFND_PRIVILEGE_PKG","schemaName":"XXCUS","sxml":""}