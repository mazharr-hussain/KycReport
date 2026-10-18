-- Release 96 (COMMON security model): data access through roles; values on the role assignment per dimension with a
-- per-object override; roles inside roles; removing a role removes its access; application ownership. Run as XXFUSION
-- on a test database (KYC installed, users REQ1 and REQ2 with role REQUESTER); everything is rolled back.
set serveroutput on
declare
    l_pass pls_integer := 0; l_fail pls_integer := 0;
    l_ur1  number; l_ur2 number; l_v varchar2(4000); l_n number;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        if p_cond then l_pass := l_pass + 1; dbms_output.put_line('PASS ' || p_label);
        else l_fail := l_fail + 1; dbms_output.put_line('FAIL ' || p_label); end if;
    end;
    function req1_role return number is
        l_id number;
    begin
        select max(ur.user_role_id) into l_id from xxfnd_user_roles ur join xxfnd_users u on u.user_id = ur.user_id
         where u.user_name = 'REQ1' and ur.role_code = 'REQUESTER' and ur.enabled_flag = 'Y';
        return l_id;
    end;
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- setup: departments, two data objects on the Department dimension, Requester reaches both by given values
    xxfnd_vpd_pkg.save_organization('COMMON', 'DEPARTMENT', 'FINANCE', 'Finance');
    xxfnd_vpd_pkg.save_organization('COMMON', 'DEPARTMENT', 'PROCUREMENT', 'Procurement');
    xxfnd_vpd_pkg.register_data_object('KYC', 'XXCMP_REQUESTS', 'KYC Requests', 'XXCMP_REQUESTS', 'DEPARTMENT',
                                       'REQUESTING_DEPARTMENT', 'REQUESTER_USER_NAME');
    xxfnd_vpd_pkg.register_data_object('KYC', 'R96_PATHS', 'Approval paths (test)', 'XXCMP_APPROVAL_PATHS', 'DEPARTMENT',
                                       'REQUESTING_DEPARTMENT');
    xxfnd_vpd_pkg.grant_data_access('KYC', 'REQUESTER', 'XXCMP_REQUESTS', 'VALUES');
    xxfnd_vpd_pkg.grant_data_access('KYC', 'REQUESTER', 'R96_PATHS', 'VALUES');
    l_ur1 := req1_role;
    ok('REQ1 holds Requester', l_ur1 is not null);

    -- default values for the dimension, then an override for one object
    xxfnd_vpd_pkg.set_assignment_values(l_ur1, 'DEPARTMENT', null, 'FINANCE,PROCUREMENT');
    l_v := xxfnd_vpd_pkg.allowed_values('XXCMP_REQUESTS', 'REQUESTING_DEPARTMENT', 'REQ1');
    ok('requests: both departments by default (' || l_v || ')', l_v = 'FINANCE,PROCUREMENT');
    l_v := xxfnd_vpd_pkg.allowed_values('XXCMP_APPROVAL_PATHS', 'REQUESTING_DEPARTMENT', 'REQ1');
    ok('second object: both departments by default (' || l_v || ')', l_v = 'FINANCE,PROCUREMENT');
    xxfnd_vpd_pkg.set_assignment_values(l_ur1, 'DEPARTMENT', 'R96_PATHS', 'FINANCE');
    l_v := xxfnd_vpd_pkg.allowed_values('XXCMP_APPROVAL_PATHS', 'REQUESTING_DEPARTMENT', 'REQ1');
    ok('second object: the override, Finance only (' || l_v || ')', l_v = 'FINANCE');
    l_v := xxfnd_vpd_pkg.allowed_values('XXCMP_REQUESTS', 'REQUESTING_DEPARTMENT', 'REQ1');
    ok('requests keep the default (' || l_v || ')', l_v = 'FINANCE,PROCUREMENT');
    xxfnd_vpd_pkg.set_assignment_values(l_ur1, 'DEPARTMENT', 'R96_PATHS', null);
    l_v := xxfnd_vpd_pkg.allowed_values('XXCMP_APPROVAL_PATHS', 'REQUESTING_DEPARTMENT', 'REQ1');
    ok('override removed: the object follows the default again (' || l_v || ')', l_v = 'FINANCE,PROCUREMENT');

    -- roles inside roles: a data role with ALL on the second object, inside a job role given to REQ2
    insert into xxfnd_roles (role_code, application_code, role_name) values ('R96_DATA', 'KYC', 'R96 data role');
    insert into xxfnd_roles (role_code, application_code, role_name) values ('R96_JOB', 'KYC', 'R96 job role');
    xxfnd_vpd_pkg.grant_data_access('KYC', 'R96_DATA', 'R96_PATHS', 'ALL');
    xxfnd_privilege_pkg.add_role_member('KYC', 'R96_JOB', 'R96_DATA');
    select max(user_id) into l_n from xxfnd_users where user_name = 'REQ2';
    -- (outside APEX ASSIGN_ROLE needs an administrator: the assignment is written directly, its application granted)
    insert into xxfnd_user_roles (user_id, employee_id, role_code)
    select user_id, employee_id, 'R96_JOB' from xxfnd_users where user_id = l_n;
    xxfnd_user_pkg.grant_application(l_n, 'KYC');
    xxfnd_vpd_pkg.clear_cache;
    l_v := nvl(xxfnd_vpd_pkg.allowed_values('XXCMP_APPROVAL_PATHS', 'REQUESTING_DEPARTMENT', 'REQ2'), '(every value)');
    ok('REQ2: all records through the role inside the job role (' || l_v || ')', l_v = '(every value)');
    select count(*) into l_n from xxfnd_user_applications ua join xxfnd_users u on u.user_id = ua.user_id
     where u.user_name = 'REQ2' and ua.application_code = 'KYC' and ua.enabled_flag = 'Y';
    ok('REQ2 has access to KYC (granted with the role)', l_n = 1);
    begin
        xxfnd_privilege_pkg.add_role_member('KYC', 'R96_DATA', 'R96_JOB');
        ok('a loop of roles is refused', false);
    exception when others then ok('a loop of roles is refused (' || sqlcode || ')', sqlcode = -20076);
    end;
    begin
        xxfnd_privilege_pkg.add_role_member('KYC', 'R96_JOB', 'COMMON_ADMIN');
        ok('a COMMON role inside a KYC role is allowed', true);
    exception when others then ok('a COMMON role inside a KYC role is allowed (' || sqlerrm || ')', false);
    end;

    -- removing the role removes its access
    select max(ur.user_role_id) into l_ur2 from xxfnd_user_roles ur join xxfnd_users u on u.user_id = ur.user_id
     where u.user_name = 'REQ2' and ur.role_code = 'R96_JOB';
    update xxfnd_user_roles set enabled_flag = 'N', end_date_active = start_date_active where user_role_id = l_ur2;
    xxfnd_vpd_pkg.clear_cache;
    select count(*) into l_n from xxfnd_user_data_access_v where user_name = 'REQ2' and data_object_code = 'R96_PATHS' and access_level = 'ALL';
    ok('REQ2 loses the access with the role', l_n = 0);

    -- application ownership: a KYC role cannot reach another application's object
    begin
        xxfnd_vpd_pkg.grant_data_access('COMMON', 'REQUESTER', 'XXCMP_REQUESTS', 'ALL');
        ok('a role of another application is refused', false);
    exception when others then ok('a role of another application is refused (' || sqlcode || ')', sqlcode = -20186);
    end;

    -- the department roles of release 76 are gone
    select count(*) into l_n from xxfnd_roles where role_code in ('REQUESTING_FINANCE', 'REQUESTING_PROCUREMENT');
    ok('department roles removed', l_n = 0);

    rollback;
    xxfnd_vpd_pkg.clear_cache;
    xxfnd_util_pkg.set_install_mode(false);
    dbms_output.put_line(l_pass || ' pass, ' || l_fail || ' fail');
exception when others then
    rollback; xxfnd_util_pkg.set_install_mode(false);
    dbms_output.put_line('ERROR ' || sqlerrm || ' ' || dbms_utility.format_error_backtrace);
    dbms_output.put_line(l_pass || ' pass, ' || (l_fail + 1) || ' fail');
end;
/
exit
