
create or replace package body xxfnd_onboard_pkg as

    function common_setting(p_name in varchar2) return varchar2 is
        l_value varchar2(4000);
    begin
        select max(s.value) into l_value
          from apex_application_settings s
         where s.application_id = (select max(apex_application_id) from xxfnd_applications where application_code = 'COMMON')
           and s.name = upper(p_name);
        return l_value;
    end common_setting;

    procedure onboard_self(p_schema           in varchar2,
                           p_application_code in varchar2 default null,
                           p_admin_user       in varchar2 default null) is
        l_ws    varchar2(255);
        l_id    number;
        l_alias varchar2(255);
        l_n     pls_integer;
    begin
        if nvl(common_setting('ONBOARD_SELF_ALLOWED'), 'Y') = 'N' then
            xxfnd_error_pkg.raise_error('XXFND_ONBOARD_SELF_OFF');
        end if;
        -- the workspace of COMMON (the APEX dictionary is read for it)
        select max(workspace) into l_ws from apex_applications
         where application_id = (select apex_application_id from xxfnd_applications where application_code = 'COMMON');
        if l_ws is not null and v('APP_ID') is null then
            apex_util.set_workspace(l_ws);
        end if;
        select count(*), max(application_id), max(alias) into l_n, l_id, l_alias
          from apex_applications x
         where x.workspace = l_ws
           and upper(x.owner) = upper(trim(p_schema))
           and (upper(x.alias) = upper(trim(p_application_code))
                or (trim(p_application_code) is null
                    and not exists (select 1 from xxfnd_applications r where r.apex_application_id = x.application_id)));
        if l_n <> 1 then
            xxfnd_error_pkg.raise_error('XXFND_ONBOARD_SELF_APP',
                                        apex_t_varchar2(upper(trim(p_schema)), nvl(upper(trim(p_application_code)), '-')));
        end if;
        xxfnd_util_pkg.set_install_mode(true);
        xxfnd_application_pkg.onboard(p_apex_application_id => l_id,
                                      p_application_code    => nvl(upper(trim(p_application_code)), upper(l_alias)),
                                      p_admin_user          => p_admin_user);
        xxfnd_util_pkg.set_install_mode(false);
    exception
        when others then
            xxfnd_util_pkg.set_install_mode(false);
            raise;
    end onboard_self;

    function is_onboarded(p_application_code in varchar2) return varchar2 is
        l_n pls_integer;
    begin
        select count(*) into l_n from xxfnd_applications where application_code = upper(trim(p_application_code));
        return case when l_n > 0 then 'Y' else 'N' end;
    end is_onboarded;

end xxfnd_onboard_pkg;
/
