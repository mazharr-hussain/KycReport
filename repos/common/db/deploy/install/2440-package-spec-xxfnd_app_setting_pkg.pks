--------------------------------------------------------------------------------
-- 21d XXFND_APP_SETTING_PKG - the Application Settings and Optional Features component of Platform (release 80).
--   COMMON only (XXFUSION). The setting and feature screens (10020-10023) call it instead of APEX API code on the
--   pages: the value of an application setting (APEX_APP_SETTING) and the status of an optional feature (an APEX
--   build option "Feature - ...") of a registered application.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxfnd_app_setting_pkg authid definer as
    -- Includes or excludes the optional feature (build option P_BUILD_OPTION_ID) of the application.
    -- P_STATUS: INCLUDE or EXCLUDE.
    procedure set_feature_status(p_application_code in varchar2, p_build_option_id in number, p_status in varchar2);
    -- The value of an application setting. APEX changes the settings of the running application only: a setting of
    -- another application is refused with a message saying where to change it.
    procedure set_value(p_application_code in varchar2, p_name in varchar2, p_value in varchar2);
end xxfnd_app_setting_pkg;
/
