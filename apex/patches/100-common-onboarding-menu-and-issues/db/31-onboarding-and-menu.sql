--------------------------------------------------------------------------------
-- 31 Basic onboarding and the application menu (release 87). COMMON only (XXFUSION), after 30.
--   XXFND_ONBOARD_PKG.ONBOARD_SELF: the bare minimum an application needs to use the common components, called from
--   the application's own install (generic script 00c-onboard-with-common.sql, run as the application's schema): it
--   registers the APEX application of that schema through XXFND_APPLICATION_PKG.ONBOARD (registration rows, grants to
--   the schema, the <CODE>_ADMIN role, the menu entries). Nothing else (no APEX setting); the full onboarding is the
--   Application Journey (page 165). IT switches it off with the COMMON setting ONBOARD_SELF_ALLOWED = N.
--   XXFND_APP_MENU_V: the menu of the running application for the common functions (entries of
--   XXFND_APP_MENU_ENTRIES the signed-in user may see, with their links): the whole navigation list of an application
--   is "select * from xxfnd_app_menu_v where app_alias = :APP_ALIAS order by display_sequence".
-- Idempotent: a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_error_pkg.register_message('XXFND_REG_WRONG_CALLER',
        'Application {1} may only be changed by itself or by COMMON (called by {2}).', -20192);
    xxfnd_error_pkg.register_message('XXFND_ONBOARD_SELF_OFF',
        'Applications may not register themselves here: ask IT to register the application in COMMON (Applications).', -20193);
    xxfnd_error_pkg.register_message('XXFND_ONBOARD_SELF_APP',
        'No single APEX application of schema {1} matches {2}: give the application code (its alias).', -20194);
    xxfnd_error_pkg.register_message('XXFND_MENU_TARGET',
        'Menu entry {1}: the target type is COMMON_PAGE, APP_PAGE, MANAGED or SHARED_SETUP, and a page needs its number.', -20195);
    commit;
end;
/

create or replace view xxfnd_app_menu_v as
select upper(a.apex_app_alias)                                   as app_alias,
       e.application_code,
       e.entry_code,
       e.parent_code,
       null                                                      as lvl,
       e.label,
       xxfnd_application_pkg.menu_url(e.application_code, e.target_type, e.page_id, e.feature_code) as target,
       'NO'                                                      as is_current,
       e.icon_css                                                as image,
       null                                                      as image_attribute,
       null                                                      as image_alt,
       e.display_sequence
  from xxfnd_app_menu_entries e
  join xxfnd_applications a on a.application_code = e.application_code
 where xxfnd_application_pkg.menu_visible(e.application_code, e.target_type, e.feature_code, e.enabled_flag) = 'Y';
comment on table xxfnd_app_menu_v is 'Release 87: the menu of an application for the common functions, for the signed-in user (an APEX list: lvl, label, target, is_current, image ...).';

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

-- every registered application gets its menu entries (only what is missing)
begin
    xxfnd_util_pkg.set_install_mode(true);
    for a in (select application_code from xxfnd_applications where application_code <> 'COMMON') loop
        xxfnd_application_pkg.ensure_menu(a.application_code);
    end loop;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
