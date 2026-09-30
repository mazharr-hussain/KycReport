create or replace package xxcus.xxfnd_security_pkg authid definer as
    -- Resolve the signed-in person. Null when the user has no active record.
    function current_employee_id return number;

    function has_role (
        p_role_code in varchar2,
        p_user_name in varchar2 default null
    ) return boolean;

    function has_role_yn (
        p_role_code in varchar2,
        p_user_name in varchar2 default null
    ) return varchar2;
    -- Comma-separated role codes; true when the user holds any of them.
    function has_any_role (
        p_role_codes in varchar2,
        p_user_name  in varchar2 default null
    ) return boolean;
    -- Y/N form of HAS_ANY_ROLE for use in SQL (report where clauses, LOVs).
    function has_any_role_yn (
        p_role_codes in varchar2,
        p_user_name  in varchar2 default null
    ) return varchar2;

    function can_view_sensitive (
        p_user_name in varchar2 default null
    ) return boolean;

    -- Four-eyes: true when acting under p_role_code would combine, on the same record,
    -- with a role the user already acted under there (p_prior_roles, SAME_RECORD rules),
    -- or when the user permanently holds a GLOBAL-conflicting role.
    function sod_conflict (
        p_role_code   in varchar2,
        p_prior_roles in apex_t_varchar2 default null,
        p_user_name   in varchar2 default null
    ) return boolean;

    -- Upserts one Fusion worker (JSON object from the HCM publicWorkers resource).
    procedure upsert_fusion_worker (
        p_worker in json_object_t
    );
    -- Pages through Fusion HCM publicWorkers using APEX's native Fusion
    -- integration web credential and refreshes FUSION rows. Run by job XXFND_HCM_SYNC.
    procedure sync_from_fusion (
        p_base_url             in varchar2,
        p_credential_static_id in varchar2,
        p_page_size            in pls_integer default 200
    );
    -- True while SYNC_FROM_FUSION runs; lets the Fusion-owned-row trigger
    -- (XXFND_EMPLOYEES_SRC) tell the sync apart from a user edit.
    function sync_running return boolean;

    -- Creates (or re-enables) a LOCAL employee and grants SYSTEM_ADMIN.
    -- Used by the installer so someone can sign in and grant further access.
    procedure bootstrap_admin (
        p_user_name in varchar2,
        p_full_name in varchar2 default null,
        p_email     in varchar2 default null
    );

end xxfnd_security_pkg;
/


-- sqlcl_snapshot {"hash":"65cb7a2833117b50b73269fd4e1ca44c676deac6","type":"PACKAGE_SPEC","name":"XXFND_SECURITY_PKG","schemaName":"XXCUS","sxml":""}