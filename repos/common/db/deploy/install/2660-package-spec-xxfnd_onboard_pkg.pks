
create or replace package xxfnd_onboard_pkg authid definer as
    -- Registers the calling application in COMMON with the bare minimum (registration rows, grants on the common
    -- objects to its schema, the role <CODE>_ADMIN given to P_ADMIN_USER when named, its menu entries), through
    -- XXFND_APPLICATION_PKG.ONBOARD. P_SCHEMA: the schema of the application's install (the generic script passes its
    -- current schema); the APEX application is the one of that schema whose alias is P_APPLICATION_CODE (or the only
    -- one of the schema not yet registered). Re-runnable: an onboarded application is refreshed, nothing it or IT set
    -- is lost. Refused when IT has switched it off (setting ONBOARD_SELF_ALLOWED = N, ORA-20193).
    procedure onboard_self(p_schema           in varchar2,
                           p_application_code in varchar2 default null,
                           p_admin_user       in varchar2 default null);
    -- Y when the application is registered in COMMON.
    function is_onboarded(p_application_code in varchar2) return varchar2;
end xxfnd_onboard_pkg;
/
