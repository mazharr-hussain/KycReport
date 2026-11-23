-- Release 94 (COMMON UI issue 8): approver types (user in use; HCM-based types are placeholders) and step deadlines.
-- Run as XXFUSION on a test database; everything is rolled back.
set serveroutput on
declare
    l_pass pls_integer := 0; l_fail pls_integer := 0;
    l_rule number; l_type varchar2(30); l_name varchar2(400); l_due timestamp with time zone;
    l_user varchar2(255);
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        if p_cond then l_pass := l_pass + 1; dbms_output.put_line('PASS ' || p_label);
        else l_fail := l_fail + 1; dbms_output.put_line('FAIL ' || p_label); end if;
    end;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select min(approval_type_code) into l_type from xxfnd_approval_types where enabled_flag = 'Y';
    if l_type is null then
        -- I-059: a database without an enabled approval type (COMMON alone): a test type, rolled back below
        xxfnd_approval_rule_pkg.register_type('R94_TEST', 'R86TEST', 'R94 test type');
        update xxfnd_approval_types set enabled_flag = 'Y' where approval_type_code = 'R94_TEST';
        l_type := 'R94_TEST';
    end if;
    select min(user_name) into l_user from xxfnd_users where enabled_flag = 'Y';
    ok('placeholder types are not available, user is',
       xxfnd_approval_rule_pkg.approver_type_available('MANAGER') = 'N'
       and xxfnd_approval_rule_pkg.approver_type_available('USER') = 'Y');
    insert into xxfnd_approval_rules (rule_id, approval_type_code, rule_name, priority, enabled_flag)
    values (xxfnd_approval_rule_s.nextval, l_type, 'R94 test rule', 0, 'Y') returning rule_id into l_rule;
    begin
        insert into xxfnd_approval_rule_steps (rule_id, step_no, step_name, approver_type)
        values (l_rule, 1, 'Manager approval', 'SUP_HIER');
        ok('saving a placeholder type is refused', false);
    exception when others then ok('saving a placeholder type is refused (' || sqlcode || ')', sqlcode = -20536);
    end;
    insert into xxfnd_approval_rule_steps (rule_id, step_no, step_name, approver_type, user_name, due_days)
    values (l_rule, 1, 'Fixed user', 'USER', l_user, 3);
    l_name := xxfnd_approval_rule_pkg.start_approval(l_type, 'R94-TXN', apex_t_varchar2(), l_user);
    l_due  := xxfnd_approval_rule_pkg.step_due_date(l_type, 'R94-TXN');
    ok('approval started with rule ' || l_name || '; current approver ' || xxfnd_approval_rule_pkg.current_approvers(l_type, 'R94-TXN'),
       xxfnd_approval_rule_pkg.current_approvers(l_type, 'R94-TXN') = upper(l_user));
    ok('step deadline 3 days: ' || to_char(l_due, 'DD-MON-YYYY'),
       trunc(cast(l_due as date)) = trunc(sysdate) + 3);
    rollback;
    xxfnd_util_pkg.set_install_mode(false);
    dbms_output.put_line(l_pass || ' pass, ' || l_fail || ' fail');
exception when others then
    rollback; xxfnd_util_pkg.set_install_mode(false);
    dbms_output.put_line('ERROR ' || sqlerrm || ' ' || dbms_utility.format_error_backtrace);
    dbms_output.put_line('FAIL unexpected error (see the line above)');
    dbms_output.put_line(l_pass || ' pass, ' || (l_fail + 1) || ' fail');
end;
/
exit
