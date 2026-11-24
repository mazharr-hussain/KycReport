
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
