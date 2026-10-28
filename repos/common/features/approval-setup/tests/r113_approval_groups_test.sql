-- COMMON 113: approval groups of a process and a rule level of approver type GROUP. Run as XXFUSION in an APEX session
-- of an administrator with Approval Setup - Manage. Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_type  xxfnd_approval_types.approval_type_code%type;
    l_app   xxfnd_approval_types.application_code%type;
    l_role  xxfnd_roles.role_code%type;
    l_n     pls_integer;
    l_users varchar2(4000);
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select min(approval_type_code) into l_type from xxfnd_approval_types;
    select max(application_code) into l_app from xxfnd_approval_types where approval_type_code = l_type;
    select min(role_code) into l_role from xxfnd_user_roles_v where active_flag = 'Y';
    if l_type is null or l_role is null then
        dbms_output.put_line('SKIP no approval type or no role with an active user');
        return;
    end if;
    xxfnd_approval_rule_pkg.save_group(l_app, l_type, 'R113_GRP', 'R113 group');
    xxfnd_approval_rule_pkg.set_group_members(l_app, 'R113_GRP', l_role, 'R113_NOBODY');
    select count(*) into l_n from xxfnd_approval_group_members where group_code = 'R113_GRP';
    ok('two members saved', l_n = 2);
    l_users := xxfnd_approval_rule_pkg.group_users('R113_GRP');
    ok('group users = the role''s users and the named user: ' || l_users, l_users like '%R113_NOBODY%');
    ok('label of a group level', xxfnd_approval_rule_pkg.approver_label('GROUP', 'R113_GRP', null) = 'Group: R113 group');
    ok('GROUP is an available approver type', xxfnd_approval_rule_pkg.approver_type_available('GROUP') = 'Y');
    xxfnd_approval_rule_pkg.set_group_members(l_app, 'R113_GRP', null, 'R113_NOBODY');
    select count(*) into l_n from xxfnd_approval_group_members where group_code = 'R113_GRP';
    ok('a member not listed is removed', l_n = 1);
    begin
        xxfnd_approval_rule_pkg.save_group(case when l_app = 'COMMON' then 'KYC' else 'COMMON' end, l_type, 'R113_X', 'x');
        ok('another application''s process refused', false);
    exception
        when others then ok('another application''s process refused', true);
    end;
    xxfnd_approval_rule_pkg.delete_group(l_app, 'R113_GRP');
    select count(*) into l_n from xxfnd_approval_groups where group_code = 'R113_GRP';
    ok('group deleted', l_n = 0);
    rollback;
end;
/
