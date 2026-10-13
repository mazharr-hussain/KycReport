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

create or replace package body xxfnd_app_setting_pkg as

    procedure check_manage(p_feature in varchar2) is
    begin
        if not xxfnd_privilege_pkg.has_privilege(p_feature, 'MANAGE') then
            raise_application_error(-20151, 'You are not allowed to change this.');
        end if;
    end check_manage;

    procedure set_feature_status(p_application_code in varchar2, p_build_option_id in number, p_status in varchar2) is
    begin
        check_manage('OPTIONAL_FEATURES');
        if upper(p_status) not in ('INCLUDE', 'EXCLUDE') then
            raise_application_error(-20152, 'Choose Include or Exclude.');
        end if;
        apex_util.set_build_option_status(p_application_id => xxfnd_application_pkg.apex_app_id(p_application_code),
                                          p_id             => p_build_option_id,
                                          p_build_status   => upper(p_status));
    end set_feature_status;

    procedure set_value(p_application_code in varchar2, p_name in varchar2, p_value in varchar2) is
    begin
        check_manage('APP_SETTINGS');
        if xxfnd_application_pkg.apex_app_id(p_application_code) <> to_number(v('APP_ID')) then
            raise_application_error(-20150, 'Change the settings of ' || p_application_code
                || ' in that application (Administration > Application Settings).');
        end if;
        apex_app_setting.set_value(p_name => p_name, p_value => p_value);
    end set_value;

end xxfnd_app_setting_pkg;
/
