-- Chunk 4: native APEX task flows inside real APEX sessions (application alias KYC).
-- Needs security_test.sql first (REQ1, REQ2, OFFICER1 and a party).
-- Release 89: KYC's RFIs run in COMMON's workflow RFI - its tasks (RFI_RESPONSE, RFI_REVIEW) belong to the COMMON
-- application (135) and are created by the workflow in the background after each commit (settle waits for it).
set serveroutput on size unlimited feedback off
@@test_users.sql
begin
    xxfusion.xxfnd_test_fixture_pkg.clear_delegations;   -- release 93: test helper (common_test_fixtures.sql, COMMON C13)
    commit;
end;
/
declare
    l_app     number;
    l_party   number;
    l_rfi     number;
    l_rfi2    number;
    l_token   varchar2(200);
    l_cat     varchar2(30);
    l_rule    number;
    l_task    number;
    l_cnt     number;
    l_state   varchar2(30);
    l_list    varchar2(4000);
    l_common  number;
    l_wf      number;

    procedure session_as(p_user varchar2) is
    begin
        if apex_application.g_instance is not null then
            apex_session.delete_session;
        end if;
        apex_session.create_session(l_app, 1, p_user);
    end;
    -- release 89: the RFI tasks are COMMON's; the other tasks (CONFIG_CHANGE) are looked up as before
    function my_tasks(p_def varchar2) return varchar2 is
        l varchar2(4000);
    begin
        select listagg(task_id || ':' || state_code, ',') within group (order by task_id) into l
          from table(apex_human_task.get_tasks(p_context => 'MY_TASKS',
                                               p_application_id => case when p_def like 'RFI%' then l_common else l_app end))
         where task_def_static_id = p_def;
        return nvl(l, '-');
    end;
    -- the workflow engine goes on in the background once the step is committed: wait until the workflow waits for a
    -- person, a wait or has ended (as in r84_notifications_test.sql)
    procedure settle is
        l_busy number;
    begin
        commit;
        for i in 1 .. 90 loop
            dbms_session.sleep(2);
            select count(*) into l_busy from apex_workflows w
             where w.workflow_id = l_wf and w.state_code = 'ACTIVE'
               and not exists (select 1 from apex_workflow_activities a
                                where a.workflow_id = w.workflow_id and a.end_time is null
                                  and upper(a.state) in ('WAITING'));
            exit when l_busy = 0 and i > 1;
        end loop;
        dbms_session.sleep(2);   -- the task actions of the step just reached
    end settle;
    function open_task(p_def varchar2) return number is
        l_id number;
    begin
        select max(task_id) into l_id from apex_tasks
         where workflow_id = l_wf and task_def_static_id = p_def and state_code in ('UNASSIGNED', 'ASSIGNED');
        return l_id;
    end open_task;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    select min(party_id) into l_party from xxcmp_parties;
    select min(lookup_code) into l_cat from xxfnd_lookup_values where lookup_type = 'RFI_CATEGORY';
    l_common := xxfnd_workflow_pkg.common_application_id;

    ------------------------------------------------------------------ RFI flow (COMMON workflow RFI)
    session_as('OFFICER1');
    apex_app_setting.set_value('MAIL_FROM', 'kyc@example.com');
    xxfnd_rfi_pkg.create_rfi('XXCMP_PARTIES', to_char(l_party), 'USER', l_cat,
                             'Please send the signed board resolution.', 'Y', trunc(sysdate) + 5,
                             p_recipient_user_name => 'REQ1', p_application_code => 'KYC', p_rfi_id => l_rfi, p_token => l_token);
    select workflow_id into l_wf from xxfnd_rfis where rfi_id = l_rfi;
    settle;
    ok('the RFI runs in COMMON''s workflow RFI (' || l_wf || ')', l_wf is not null);
    l_task := open_task('RFI_RESPONSE');
    ok('RFI to REQ1: the workflow creates an RFI_RESPONSE task (' || l_task || ')', l_task is not null);
    select count(*) into l_cnt from apex_tasks where task_id = l_task and application_id = l_common;
    ok('the task belongs to the COMMON application (' || l_common || ')', l_cnt = 1);
    select count(*) into l_cnt from apex_task_participants where task_id = l_task and participant = 'REQ1' and participant_type = 'POTENTIAL_OWNER';
    ok('REQ1 is its potential owner', l_cnt = 1);
    select count(*) into l_cnt from xxfnd_notifications
     where task_id = l_task and event_code = 'TASK_ASSIGNED' and user_name = 'REQ1';
    ok('REQ1 is told (COMMON notification TASK_ASSIGNED): ' || l_cnt, l_cnt >= 1);

    session_as('REQ1');
    l_list := my_tasks('RFI_RESPONSE');
    ok('REQ1 sees it in My Tasks: ' || l_list, instr(l_list, to_char(l_task)) > 0);
    session_as('REQ2');
    ok('REQ2 does not: ' || my_tasks('RFI_RESPONSE'), instr(my_tasks('RFI_RESPONSE'), to_char(l_task)) = 0);

    session_as('REQ1');
    xxfnd_rfi_pkg.respond(l_rfi, to_clob('Attached, signed on 1 Sept.'));
    settle;
    select state_code into l_state from apex_tasks where task_id = l_task;
    ok('responding completes the RFI_RESPONSE task: ' || l_state, l_state = 'COMPLETED');
    l_task := open_task('RFI_REVIEW');
    ok('and the workflow creates an RFI_REVIEW task (' || l_task || ')', l_task is not null);

    session_as('OFFICER1');
    ok('OFFICER1 (who raised it) sees the review: ' || my_tasks('RFI_REVIEW'), instr(my_tasks('RFI_REVIEW'), to_char(l_task)) > 0);
    xxfnd_rfi_pkg.resolve(l_rfi, 'RESOLVED', 'Complete.');
    settle;
    select state_code into l_state from apex_tasks where task_id = l_task;
    ok('resolving completes the RFI_REVIEW task: ' || l_state, l_state = 'COMPLETED');
    ok('and the workflow ends: ' || xxfnd_workflow_pkg.state(l_wf), xxfnd_workflow_pkg.state(l_wf) = 'COMPLETED');

    ------------------------------------------------------------ delegation
    xxfusion.xxfnd_test_fixture_pkg.add_delegation('REQ1', 'REQ2', trunc(sysdate), trunc(sysdate) + 7, 'Annual leave');
    xxfnd_rfi_pkg.create_rfi('XXCMP_PARTIES', to_char(l_party), 'USER', l_cat,
                             'Second request while REQ1 is away.', 'Y', trunc(sysdate) + 5,
                             p_recipient_user_name => 'REQ1', p_application_code => 'KYC', p_rfi_id => l_rfi2, p_token => l_token);
    select workflow_id into l_wf from xxfnd_rfis where rfi_id = l_rfi2;
    settle;
    l_task := open_task('RFI_RESPONSE');
    select listagg(participant, ',') within group (order by participant) into l_list
      from apex_task_participants where task_id = l_task and participant_type = 'POTENTIAL_OWNER';
    ok('delegation REQ1 -> REQ2 adds REQ2 as owner: ' || l_list, l_list = 'REQ1,REQ2');
    session_as('REQ2');
    select count(*) into l_cnt from xxfnd_rfis where rfi_id = l_rfi2;
    ok('the delegate REQ2 can see the delegated RFI (data security)', l_cnt = 1);
    ok('and has the task in My Tasks: ' || my_tasks('RFI_RESPONSE'), instr(my_tasks('RFI_RESPONSE'), to_char(l_task)) > 0);
    session_as('OFFICER1');
    xxfnd_rfi_pkg.resolve(l_rfi2, 'CANCELLED', 'Test cleanup.');
    settle;
    select max(state_code) into l_state from apex_tasks where task_id = l_task;
    ok('cancelling the RFI ends its workflow (' || xxfnd_workflow_pkg.state(l_wf) || ') and its task (' || nvl(l_state, 'removed') || ')',
       xxfnd_workflow_pkg.state(l_wf) in ('TERMINATED', 'COMPLETED')
       and (l_state is null or l_state not in ('UNASSIGNED', 'ASSIGNED')));
    xxfusion.xxfnd_test_fixture_pkg.clear_delegations;
    commit;

    ------------------------------------------------------- maker-checker change
    session_as('MGR1');
    delete from xxcmp_attachment_rules where entity_name = 'XXCMP_PARTIES' and jurisdiction = 'QA';   -- earlier test run
    insert into xxcmp_attachment_rules (entity_name, category_code, jurisdiction, mandatory_flag, priority)
    values ('XXCMP_PARTIES', (select min(category_code) from xxfnd_document_categories), 'QA', 'Y', 50)
    returning attachment_rule_id into l_rule;
    xxfnd_approval_pkg.request('XXCMP_ATTACHMENT_RULES', to_char(l_rule));
    commit;
    select max(task_id) into l_task from apex_tasks
     where task_def_static_id = 'CONFIG_CHANGE' and detail_pk = 'XXCMP_ATTACHMENT_RULES:' || l_rule;
    ok('submitting a change creates a CONFIG_CHANGE task (' || l_task || ')', l_task is not null);
    ok('the maker (MGR1) may neither claim nor approve it',
       not apex_human_task.is_allowed(p_task_id => l_task, p_operation => apex_human_task.c_task_op_claim)
       and not apex_human_task.is_allowed(p_task_id => l_task, p_operation => apex_human_task.c_task_op_approve));

    -- the approval itself (who sees, claims and approves the task) is COMMON's CONFIG_CHANGE workflow, tested by COMMON;
    -- KYC checks only that its change starts it (the task belongs to COMMON's application since COMMON 84)

    ------------------------------------------------------------ deadlines
    -- release 89: task deadlines are COMMON's (XXFND_WORKFLOW_PKG.PROCESS_DEADLINES, automation task-deadlines of COMMON
    -- for every application); COMMON's RFI tasks carry no due date, so KYC checks only that the run works and that a
    -- second run sends nothing again
    session_as('OFFICER1');
    xxfnd_workflow_pkg.process_deadlines;
    select count(*) into l_cnt from xxfnd_task_alerts;
    xxfnd_workflow_pkg.process_deadlines;
    select count(*) into l_list from xxfnd_task_alerts;
    ok('COMMON''s deadline run works and a second run adds no alert (' || l_cnt || ' / ' || l_list || ')', l_cnt = to_number(l_list));
    commit;
    apex_session.delete_session;
end;
/
exit
