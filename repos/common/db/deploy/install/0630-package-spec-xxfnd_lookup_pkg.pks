--------------------------------------------------------------------------------
-- 05c XXFND_LOOKUP_PKG - the Lookups component of Reference Data (release 80). COMMON only (XXFUSION).
--   The lookup helpers moved here from XXFND_UTIL_PKG (old callers break on purpose: no wrappers): the meaning of a
--   value in the session language (English when not translated), the check that a value is active.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxfnd_lookup_pkg authid definer as
    -- The meaning of a lookup value in the session language (falls back to English, then to the code).
    function lookup_meaning(p_lookup_type in varchar2, p_lookup_code in varchar2) return varchar2;
    -- True when the value exists and is active today.
    function is_valid_lookup(p_lookup_type in varchar2, p_lookup_code in varchar2) return boolean;
    -- Raises ORA-20100 (with P_LABEL) when a given value is not an active value of the lookup type.
    procedure assert_lookup(p_lookup_type in varchar2, p_lookup_code in varchar2, p_label in varchar2);

    -- Release 86: registration by an application. Added only when missing; what an administrator changed is kept;
    -- a re-run does nothing. The application must be registered (ORA-20180); a lookup type of another application
    -- is refused (ORA-20186). COMMON's rows are the instance's (no application). No APEX session needed.
    procedure register_lookup_type(p_application_code    in varchar2,
                                   p_lookup_type         in varchar2,
                                   p_meaning             in varchar2,
                                   p_customization_level in varchar2 default 'E',
                                   p_description         in varchar2 default null);
    -- A value of a lookup type (ORA-20187 when the type is not registered); P_MEANING_AR: its Arabic meaning.
    procedure register_lookup_value(p_application_code   in varchar2,
                                    p_lookup_type        in varchar2,
                                    p_lookup_code        in varchar2,
                                    p_meaning            in varchar2,
                                    p_display_sequence   in number   default null,
                                    p_description        in varchar2 default null,
                                    p_tag                in varchar2 default null,
                                    p_parent_lookup_type in varchar2 default null,
                                    p_parent_lookup_code in varchar2 default null,
                                    p_meaning_ar         in varchar2 default null);
    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    procedure unregister_lookup_value(p_application_code in varchar2, p_lookup_type in varchar2, p_lookup_code in varchar2);
    -- the type with its values
    procedure unregister_lookup_type(p_application_code in varchar2, p_lookup_type in varchar2);
    -- every lookup type of the application with its values (XXFND_APPLICATION_PKG.DELETE_APPLICATION)
    procedure unregister_application(p_application_code in varchar2);
end xxfnd_lookup_pkg;
/
