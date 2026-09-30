create or replace package body xxcus.xxfnd_privilege_pkg as

    function norm_user (
        p_user_name in varchar2
    ) return varchar2 is
    begin
        return upper(nvl(p_user_name, xxfnd_util_pkg.current_user));
    end norm_user;

    function has_privilege (
        p_feature_code in varchar2,
        p_action       in varchar2,
        p_user_name    in varchar2 default null
    ) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);   -- private function: not callable inside SQL
    begin
        select
            count(*)
        into l_count
        from
                 xxfnd_user_roles_v ur
            join xxfnd_role_privileges rp on rp.role_code = ur.role_code
            join xxfnd_privileges      p on p.privilege_code = rp.privilege_code
            join xxfnd_features        f on f.feature_code = p.feature_code
        where
                ur.user_name = l_user
            and ur.active_flag = 'Y'
            and f.enabled_flag = 'Y'
            and p.feature_code = upper(p_feature_code)
            and p.action_code = upper(p_action)
            and rownum = 1;

        return l_count > 0;
    end has_privilege;

    function has_privilege_yn (
        p_feature_code in varchar2,
        p_action       in varchar2,
        p_user_name    in varchar2 default null
    ) return varchar2 is
    begin
        return
            case
                when has_privilege(p_feature_code, p_action, p_user_name) then
                    'Y'
                else
                    'N'
            end;
    end has_privilege_yn;

    function page_feature (
        p_page_id   in number,
        p_app_alias in varchar2
    ) return varchar2 is
        l_feature xxfnd_feature_pages.feature_code%type;
    begin
        select
            max(feature_code)
        into l_feature
        from
            xxfnd_feature_pages
        where
                upper(app_alias) = upper(nvl(p_app_alias,
                                             v('APP_ALIAS')))
            and page_id = p_page_id;

        return l_feature;
    end page_feature;

    function has_page_privilege (
        p_page_id   in number,
        p_action    in varchar2,
        p_app_alias in varchar2 default null
    ) return boolean is
        l_feature xxfnd_feature_pages.feature_code%type := page_feature(p_page_id, p_app_alias);
    begin
        return
            l_feature is not null
            and has_privilege(l_feature, p_action);
    end has_page_privilege;

    function has_page_request_privilege (
        p_page_id   in number,
        p_request   in varchar2,
        p_app_alias in varchar2 default null
    ) return boolean is
    begin
        return has_page_privilege(p_page_id,
                                  case
                                      when upper(p_request) = 'CREATE' then
                                          'CREATE'
                                      else
                                          'MANAGE'
                                  end,
                                  p_app_alias);
    end has_page_request_privilege;

    function has_any_privilege (
        p_user_name in varchar2 default null
    ) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select
            count(*)
        into l_count
        from
                 xxfnd_user_roles_v ur
            join xxfnd_role_privileges rp on rp.role_code = ur.role_code
        where
                ur.user_name = l_user
            and ur.active_flag = 'Y'
            and rownum = 1;

        return l_count > 0;
    end has_any_privilege;

    function has_any_admin_privilege (
        p_user_name in varchar2 default null
    ) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select
            count(*)
        into l_count
        from
                 xxfnd_user_roles_v ur
            join xxfnd_role_privileges rp on rp.role_code = ur.role_code
            join xxfnd_privileges      p on p.privilege_code = rp.privilege_code
            join xxfnd_features        f on f.feature_code = p.feature_code
        where
                ur.user_name = l_user
            and ur.active_flag = 'Y'
            and f.admin_flag = 'Y'
            and f.enabled_flag = 'Y'
            and rownum = 1;

        return l_count > 0;
    end has_any_admin_privilege;

    function role_privilege_list (
        p_role_code in varchar2
    ) return varchar2 is
        l_list varchar2(32767);
    begin
        select
            listagg(privilege_code, ':') within group(
            order by
                privilege_code
            )
        into l_list
        from
            xxfnd_role_privileges
        where
            role_code = p_role_code;

        return l_list;
    end role_privilege_list;

    procedure set_role_privileges (
        p_role_code      in varchar2,
        p_privilege_list in varchar2
    ) is
        l_wanted apex_t_varchar2 := apex_string.split(p_privilege_list, ':');
    begin
        delete from xxfnd_role_privileges
        where
                role_code = p_role_code
            and privilege_code not in (
                select
                    column_value
                from
                    table ( l_wanted )
            );

        insert into xxfnd_role_privileges (
            role_code,
            privilege_code
        )
            select
                p_role_code,
                p.privilege_code
            from
                xxfnd_privileges p
            where
                p.privilege_code in (
                    select
                        column_value
                    from
                        table ( l_wanted )
                )
                and not exists (
                    select
                        1
                    from
                        xxfnd_role_privileges rp
                    where
                            rp.role_code = p_role_code
                        and rp.privilege_code = p.privilege_code
                );

    end set_role_privileges;

end xxfnd_privilege_pkg;
/


-- sqlcl_snapshot {"hash":"d06805884c3c722190c217694fc96f9f0f6fff48","type":"PACKAGE_BODY","name":"XXFND_PRIVILEGE_PKG","schemaName":"XXCUS","sxml":""}