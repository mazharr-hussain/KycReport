--------------------------------------------------------------------------------
-- 20 COMMON application seed (release 49). Installed by the COMMON application only.
--   The COMMON application (code and alias COMMON) runs on the XXFUS schema and holds what every
--   application shares: security, flexfield and attachment setup, workflow. Its own access:
--     role    COMMON_ADMIN  - administers the shared setup
--     feature COMMON_HOME   - the home page (page 1)
--   The developer installing the application (or the workspace administrators, when installed without
--   an APEX session) becomes the first COMMON_ADMIN.
-- Idempotent: rows are inserted once; administrators maintain them on the setup screens.
--------------------------------------------------------------------------------
declare
    l_app   number;
    l_user  varchar2(255);
    l_name  varchar2(240);
    l_email varchar2(320);
begin
    xxfnd_util_pkg.set_install_mode(true);
    select application_id into l_app from xxfnd_applications where application_code = 'COMMON';

    merge into xxfnd_roles t using (select 'COMMON_ADMIN' role_code from dual) s on (t.role_code = s.role_code)
     when not matched then insert (role_code, application_code, application_id, role_name, description)
                           values (s.role_code, 'COMMON', l_app, 'Common Administrator',
                                   'Maintains the setup every application shares: users and access, flexfields, attachments, workflow.');

    merge into xxfnd_features t using (select 'COMMON_HOME' feature_code from dual) s on (t.feature_code = s.feature_code)
     when not matched then insert (feature_code, feature_name, feature_group, display_sequence, admin_flag, application_id)
                           values (s.feature_code, 'Common Home', 'BUSINESS', 10, 'N', l_app);
    merge into xxfnd_privileges t using (select 'COMMON_HOME.VIEW' privilege_code from dual) s
       on (t.privilege_code = s.privilege_code)
     when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                           values (s.privilege_code, 'COMMON_HOME', 'VIEW', 'Common Home - View');
    merge into xxfnd_feature_pages t using (select 'COMMON' app_alias, 1 page_id from dual) s
       on (t.app_alias = s.app_alias and t.page_id = s.page_id)
     when not matched then insert (app_alias, page_id, feature_code) values (s.app_alias, s.page_id, 'COMMON_HOME');
    merge into xxfnd_role_privileges t using (select 'COMMON_ADMIN' rc, 'COMMON_HOME.VIEW' pc from dual) s
       on (t.role_code = s.rc and t.privilege_code = s.pc)
     when not matched then insert (role_code, privilege_code) values (s.rc, s.pc);

    -- first administrator
    l_user := sys_context('APEX$SESSION', 'APP_USER');
    if l_user is not null then
        begin
            execute immediate q'[
                select max(trim(u.first_name || ' ' || u.last_name)), max(u.email)
                  from apex_workspace_apex_users u
                 where upper(u.user_name) = upper(:1)]'
                into l_name, l_email using l_user;
        exception
            when others then
                null;
        end;
        xxfnd_security_pkg.bootstrap_admin(l_user, l_name, l_email, 'COMMON_ADMIN');
    else
        for a in (select user_name, trim(first_name || ' ' || last_name) full_name, email
                    from apex_workspace_apex_users
                   where is_admin = 'Yes' and nvl(account_locked, 'No') = 'No') loop
            xxfnd_security_pkg.bootstrap_admin(a.user_name, a.full_name, a.email, 'COMMON_ADMIN');
        end loop;
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
