set feedback off
declare l_emp number;
begin
    xxfnd_util_pkg.set_install_mode(true);
    merge into xxfnd_roles t using (select 'PARTY_VIEWER' c from dual) s on (t.role_code = s.c)
     when not matched then insert (role_code, application_code, role_name) values ('PARTY_VIEWER', (select min(application_code) from xxfnd_roles), 'Party Viewer (test)');
    merge into xxfnd_role_privileges t using (select 'PARTY_VIEWER' r, 'PARTIES.VIEW' p from dual) s on (t.role_code=s.r and t.privilege_code=s.p)
     when not matched then insert (role_code, privilege_code) values (s.r, s.p);
    merge into xxfnd_data_security_rules t using (select 'PARTY_VIEWER' r from dual) s on (t.role_code=s.r and t.table_name='XXCMP_PARTIES')
     when not matched then insert (role_code, table_name, rule_type) values ('PARTY_VIEWER','XXCMP_PARTIES','ALL_ROWS');
    select employee_id into l_emp from xxfnd_employees where user_name='REQ2';
    merge into xxfnd_user_roles t using (select l_emp e from dual) s on (t.employee_id=s.e and t.role_code='PARTY_VIEWER' and t.end_date_active is null)
     when not matched then insert (employee_id, role_code) values (l_emp, 'PARTY_VIEWER');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
end;
/
exit
