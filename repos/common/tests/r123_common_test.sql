-- COMMON 123 (release 126: the role grants outside an APEX session): routines for applications (delegations, approval rules and role grants switched off / on, lookup values
-- changed), status tones of lookup values, approval groups in GROUP_CODE. Run as XXFUSION in an APEX session of a
-- COMMON administrator (COMMON application, any page). Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_n     pls_integer;
    l_id    number;
    l_date  date;
    l_type  varchar2(30);
    l_app   varchar2(30);
    l_code  varchar2(30);
    l_user  varchar2(255);
    l_role  varchar2(30);
    l_flag  varchar2(1);
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function other(p_app varchar2) return varchar2 is
    begin
        return case when p_app = 'COMMON' then 'KYC' else 'COMMON' end;
    end;
begin
    apex_util.set_workspace('XXCUS');
    apex_session.create_session(p_app_id => 135, p_page_id => 1, p_username => 'ADMIN');

    -- I-012: delegations through routines (the signed-in user delegates)
    l_id := xxfnd_workflow_pkg.add_delegation('COMMON', v('APP_USER'), 'R123_DELEGATE', trunc(sysdate), trunc(sysdate) + 5,
                                              p_reason => 'R123');
    select count(*) into l_n from xxfnd_wf_delegations where delegation_id = l_id and delegate_user_name = 'R123_DELEGATE';
    ok('ADD_DELEGATION adds the delegation', l_n = 1);
    xxfnd_workflow_pkg.end_delegation('COMMON', l_id, trunc(sysdate) + 1);
    select end_date into l_date from xxfnd_wf_delegations where delegation_id = l_id;
    ok('END_DELEGATION ends it on the given day', l_date = trunc(sysdate) + 1);
    begin
        xxfnd_workflow_pkg.end_delegation('COMMON', -1);
        ok('an unknown delegation is refused', false);
    exception
        when others then ok('an unknown delegation is refused', sqlcode = -20187);
    end;

    -- I-013: an approval rule switched off and on by its application
    select min(approval_type_code) into l_type from xxfnd_approval_types;
    if l_type is null then
        dbms_output.put_line('SKIP no approval type');
    else
        select application_code into l_app from xxfnd_approval_types where approval_type_code = l_type;
        xxfnd_approval_rule_pkg.register_rule(l_app, l_type, 'R123 rule', apex_t_varchar2('First=REQUESTER'));
        xxfnd_approval_rule_pkg.set_rule_enabled(l_app, l_type, 'R123 rule', 'N');
        select enabled_flag into l_flag from xxfnd_approval_rules where approval_type_code = l_type and rule_name = 'R123 rule';
        ok('SET_RULE_ENABLED switches a rule off', l_flag = 'N');
        xxfnd_approval_rule_pkg.set_rule_enabled(l_app, l_type, 'R123 rule', 'Y');
        select enabled_flag into l_flag from xxfnd_approval_rules where approval_type_code = l_type and rule_name = 'R123 rule';
        ok('SET_RULE_ENABLED switches it on again', l_flag = 'Y');
        begin
            xxfnd_approval_rule_pkg.set_rule_enabled(other(l_app), l_type, 'R123 rule', 'N');
            ok('another application''s rule is refused', false);
        exception
            when others then ok('another application''s rule is refused', sqlcode in (-20186, -20180));
        end;

        -- I-026: a group level keeps its group in GROUP_CODE (ROLE_CODE stays empty); the group cannot be deleted while used
        xxfnd_approval_rule_pkg.save_group(l_app, l_type, 'R123_GRP', 'R123 group');
        insert into xxfnd_approval_rule_steps (rule_id, step_no, step_name, approver_type, group_code)
        select rule_id, 99, 'R123 group level', 'GROUP', 'R123_GRP'
          from xxfnd_approval_rules where approval_type_code = l_type and rule_name = 'R123 rule';
        ok('a GROUP level is saved with GROUP_CODE only', sql%rowcount = 1);
        begin
            xxfnd_approval_rule_pkg.delete_group(l_app, 'R123_GRP');
            ok('a group used by a level cannot be deleted', false);
        exception
            when others then ok('a group used by a level cannot be deleted', sqlcode = -20537);
        end;
        begin
            insert into xxfnd_approval_rule_steps (rule_id, step_no, step_name, approver_type, role_code)
            select rule_id, 98, 'R123 old style', 'GROUP', 'R123_GRP'
              from xxfnd_approval_rules where approval_type_code = l_type and rule_name = 'R123 rule';
            ok('a GROUP level without GROUP_CODE is refused (CK8)', false);
        exception
            when others then ok('a GROUP level without GROUP_CODE is refused (CK8)', sqlcode = -2290);
        end;
        select count(*) into l_n from xxfnd_approval_rule_steps where approver_type = 'GROUP' and group_code is null;
        ok('no group level left in ROLE_CODE after the upgrade', l_n = 0);
    end if;

    -- I-014 / I-010: an application changes its own lookup value; its tone
    select max(t.lookup_type), max(t.application_code), max(v.lookup_code)
      into l_type, l_app, l_code
      from xxfnd_lookup_types t
      join xxfnd_lookup_values v on v.lookup_type = t.lookup_type
     where t.application_code is not null and rownum = 1;
    if l_type is null then
        dbms_output.put_line('SKIP no lookup value of an application');
    else
        xxfnd_lookup_pkg.update_lookup_value(l_app, l_type, l_code, p_meaning => 'R123 meaning', p_tone => 'Success');
        select count(*) into l_n from xxfnd_lookup_values
         where lookup_type = l_type and lookup_code = l_code and meaning = 'R123 meaning' and tone = 'success';
        ok('UPDATE_LOOKUP_VALUE changes the meaning and the tone', l_n = 1);
        ok('LOOKUP_TONE reads the tone', xxfnd_lookup_pkg.lookup_tone(l_type, l_code) = 'success');
        ok('LOOKUP_TONE is neutral for an unknown value', xxfnd_lookup_pkg.lookup_tone(l_type, 'R123_NONE') = 'neutral');
        select count(*) into l_n from xxfnd_lookup_values_vl where lookup_type = l_type and lookup_code = l_code and tone = 'success';
        ok('XXFND_LOOKUP_VALUES_VL shows the tone', l_n = 1);
        begin
            xxfnd_lookup_pkg.update_lookup_value(other(l_app), l_type, l_code, p_meaning => 'x');
            ok('another application''s value is refused', false);
        exception
            when others then ok('another application''s value is refused', sqlcode in (-20186, -20180));
        end;
        begin
            xxfnd_lookup_pkg.update_lookup_value(l_app, l_type, 'R123_NONE', p_meaning => 'x');
            ok('an unknown value is refused', false);
        exception
            when others then ok('an unknown value is refused', sqlcode = -20187);
        end;
        begin
            update xxfnd_lookup_values set tone = 'pink' where lookup_type = l_type and lookup_code = l_code;
            ok('an unknown tone is refused (CK3)', false);
        exception
            when others then ok('an unknown tone is refused (CK3)', sqlcode = -2290);
        end;
    end if;
    select max(lookup_type) into l_type from xxfnd_lookup_types where application_code is null
       and exists (select 1 from xxfnd_lookup_values v where v.lookup_type = xxfnd_lookup_types.lookup_type);
    if l_type is not null then
        select max(lookup_code) into l_code from xxfnd_lookup_values where lookup_type = l_type;
        begin
            xxfnd_lookup_pkg.update_lookup_value('KYC', l_type, l_code, p_meaning => 'x');
            ok('a COMMON shared value is refused for an application', false);
        exception
            when others then ok('a COMMON shared value is refused for an application', sqlcode in (-20186, -20180));
        end;
    end if;

    -- I-013: a user's grant of an application's role switched off and on by that application. In an APEX session the
    -- signed-in user needs the role-assignment privilege; outside one (an application's job or install) the
    -- application's own role is enough (release 126)
    select max(ur.user_name), max(r.role_code), max(r.application_code)
      into l_user, l_role, l_app
      from xxfnd_user_roles_v ur
      join xxfnd_roles r on r.role_code = ur.role_code
     where ur.active_flag = 'Y' and r.application_code is not null and rownum = 1;
    if l_role is null then
        dbms_output.put_line('SKIP no active grant of an application role');
    else
        if not (xxfnd_privilege_pkg.has_privilege('USERS_ACCESS', 'MANAGE')
                or xxfnd_privilege_pkg.has_privilege('ROLES_PRIVILEGES', 'MANAGE')) then
            begin
                xxfnd_user_pkg.set_role_enabled(l_app, l_user, l_role, 'N');
                ok('in an APEX session without the privilege the change is refused', false);
            exception
                when others then ok('in an APEX session without the privilege the change is refused', sqlcode = -20072);
            end;
        end if;
        apex_session.delete_session;   -- as an application's background job: no signed-in user
        xxfnd_user_pkg.set_role_enabled(l_app, l_user, l_role, 'N');
        select count(*) into l_n from xxfnd_user_roles_v where user_name = l_user and role_code = l_role and active_flag = 'Y';
        ok('SET_ROLE_ENABLED switches the grant off', l_n = 0);
        xxfnd_user_pkg.set_role_enabled(l_app, l_user, l_role, 'Y');
        select count(*) into l_n from xxfnd_user_roles_v where user_name = l_user and role_code = l_role and active_flag = 'Y';
        ok('SET_ROLE_ENABLED switches it on again', l_n = 1);
        begin
            xxfnd_user_pkg.set_role_enabled(other(l_app), l_user, l_role, 'N');
            ok('another application''s role is refused', false);
        exception
            when others then ok('another application''s role is refused', sqlcode in (-20186, -20180));
        end;
    end if;
    rollback;
end;
/
