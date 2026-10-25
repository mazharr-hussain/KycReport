
--------------------------------------------------------------------------------
-- Row-level data security (Virtual Private Database)
--------------------------------------------------------------------------------
create or replace package xxfnd_vpd_pkg authid definer as
    -- DBMS_RLS policy function for every table that has data security rules.
    function policy(p_schema in varchar2, p_object in varchar2) return varchar2;
    -- Narrow bypass for server code that has already authorised the caller
    -- (e.g. a validated RFI response token). Always paired with end_trusted.
    procedure begin_trusted;
    -- Release 84: Y-state of that bypass (or a background job, as the policy): the other row policies of the setup
    -- (the administration scope of XXFND_APPLICATION_PKG) honour it too.
    function is_trusted return boolean;
    procedure end_trusted;
    -- Release 74 (R23): the predicate of a user and table is kept for a few seconds in the APEX session (a report
    -- that calls a function per row runs the policy once, not once per row). CLEAR_CACHE forgets it at once.
    procedure clear_cache;
    -- Release 76: the values of P_COLUMN in P_TABLE the user's data security allows, for a form's list of values and
    -- the save check: null = every value (a rule for all rows or for the user's own records), otherwise the
    -- comma-separated values of the user's "column in list" rules on that column ('#NONE' when no rule gives any).
    function allowed_values(p_table in varchar2, p_column in varchar2, p_user in varchar2 default null) return varchar2;
    -- Release 79: assign a data access rule to a user (P_USER_ID) or a role (P_ROLE_CODE); nothing happens when it is
    -- assigned already. The same call serves the User, Role and Data access rule screens.
    procedure assign_rule(p_rule_id in number, p_user_id in number default null, p_role_code in varchar2 default null);
    procedure unassign_rule(p_assignment_id in number);

    -- Release 86: a data access rule of a role of the application (registration: added only when the role has no
    -- rule of that type on that table and column; assigned to the role). The application must be registered
    -- (ORA-20180) and own the role (ORA-20186). The table gets its policy from the application's own install
    -- (XXFND_SCHEMA_PKG.APPLY_POLICIES in its schema).
    procedure register_data_rule(p_application_code in varchar2,
                                 p_role_code        in varchar2,
                                 p_table_name       in varchar2,
                                 p_rule_type        in varchar2,
                                 p_column_name      in varchar2 default null,
                                 p_value_list       in varchar2 default null,
                                 p_description      in varchar2 default null);

    ----------------------------------------------------------------------------
    -- Release 96: the security model (09a). Data access only through roles; it decides which records (privileges
    -- decide what). Every routine takes the application and changes only its rows (COMMON administrator: any).
    ----------------------------------------------------------------------------
    -- A dimension (what access is decided by): VALUE_SOURCE ORGANIZATION (P_ORGANIZATION_TYPE), LOOKUP (P_LOOKUP_TYPE)
    -- or FREE. Added when missing, otherwise its name and source are updated.
    procedure register_dimension(p_application_code  in varchar2,
                                 p_dimension_code    in varchar2,
                                 p_dimension_name    in varchar2,
                                 p_value_source      in varchar2 default 'ORGANIZATION',
                                 p_organization_type in varchar2 default null,
                                 p_lookup_type       in varchar2 default null,
                                 p_description       in varchar2 default null);
    -- A department / organization (type, code): added or updated; P_PARENT_CODE of the same type.
    procedure save_organization(p_application_code  in varchar2,
                                p_organization_type in varchar2,
                                p_organization_code in varchar2,
                                p_organization_name in varchar2,
                                p_parent_code       in varchar2 default null,
                                p_enabled_flag      in varchar2 default 'Y',
                                p_source_type       in varchar2 default 'LOCAL',
                                p_fusion_id         in varchar2 default null);
    -- A secured table of the application: P_DIMENSION_COLUMN holds the dimension's value, P_OWNER_COLUMN the owner.
    -- Release 102: P_DIMENSION_VALUE_TYPE CODE (default) - the column holds the value code; ID - it holds
    -- XXHR_ORGANIZATIONS.ORGANIZATION_ID (a dimension of value source ORGANIZATION). Null keeps a registered object's type.
    procedure register_data_object(p_application_code in varchar2,
                                   p_data_object_code in varchar2,
                                   p_object_name      in varchar2,
                                   p_table_name       in varchar2,
                                   p_dimension_code   in varchar2 default null,
                                   p_dimension_column in varchar2 default null,
                                   p_owner_column     in varchar2 default null,
                                   p_description      in varchar2 default null,
                                   p_dimension_value_type in varchar2 default null);
    -- A role reaches the records of a data object at a level: ALL, VALUES (the assignment's values) or OWN.
    procedure grant_data_access(p_application_code in varchar2, p_role_code in varchar2,
                                p_data_object_code in varchar2, p_access_level in varchar2);
    procedure revoke_data_access(p_application_code in varchar2, p_role_code in varchar2,
                                 p_data_object_code in varchar2, p_access_level in varchar2 default null);
    -- The values of a user's role assignment for a dimension: P_DATA_OBJECT_CODE null = the default of every object of
    -- the dimension, set = an override for that object. P_VALUES (comma-separated) replace the current ones; empty
    -- removes them (an override removed = the object follows the default again).
    procedure set_assignment_values(p_user_role_id     in number,
                                    p_dimension_code   in varchar2,
                                    p_data_object_code in varchar2 default null,
                                    p_values           in varchar2 default null);
    function assignment_values(p_user_role_id in number, p_dimension_code in varchar2,
                               p_data_object_code in varchar2 default null) return varchar2;
    -- the application's dimensions, organizations and data objects (XXFND_APPLICATION_PKG.DELETE_APPLICATION)
    procedure unregister_application(p_application_code in varchar2);
end xxfnd_vpd_pkg;
/
