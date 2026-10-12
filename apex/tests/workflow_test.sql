-- Chunk 4: native APEX task flows inside real APEX sessions (application alias KYC).
-- Needs security_test.sql first (REQ1, REQ2, OFFICER1 and a party).
set serveroutput on size unlimited feedback off
@@test_users.sql
begin
    delete from xxfnd_wf_delegations;
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

    procedure session_as(p_user varchar2) is
    begin
        if apex_application.g_instance is not null then
            apex_session.delete_session;
        end if;
        apex_session.create_session(l_app, 1, p_user);
    end;
    function my_tasks(p_def varchar2) return varchar2 is
        l varchar2(4000);
    begin
        select listagg(task_id || ':' || state_code, ',') within group (order by task_id) into l
          from table(apex_human_task.get_tasks(p_context => 'MY_TASKS', p_application_id => l_app))
         where task_def_static_id = p_def;
        return nvl(l, '-');
    end;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    select min(party_id) into l_party from xxcmp_parties;
    select min(lookup_code) into l_cat from xxfnd_lookup_values where lookup_type = 'RFI_CATEGORY';

    ------------------------------------------------------------------ RFI flow
    session_as('OFFICER1');
    apex_app_setting.set_value('MAIL_FROM', 'kyc@example.com');
    xxfnd_rfi_pkg.create_rfi('XXCMP_PARTIES', to_char(l_party), 'USER', l_cat,
                             'Please send the signed board resolution.', 'Y', trunc(sysdate) + 5,
                             p_recipient_user_name => 'REQ1', p_application_code => 'KYC', p_rfi_id => l_rfi, p_token => l_token);
    commit;
    select response_task_id into l_task from xxfnd_rfis where rfi_id = l_rfi;
    ok('RFI to REQ1 creates an RFI_RESPONSE task (' || l_task || ')', l_task is not null);
    select count(*) into l_cnt from apex_task_participants where task_id = l_task and participant = 'REQ1' and participant_type = 'POTENTIAL_OWNER';
    ok('REQ1 is its potential owner', l_cnt = 1);
    select count(*) into l_cnt from apex_mail_queue where mail_to = 'req1@example.com' and mail_subj like 'Action needed:%';
    ok('REQ1 is e-mailed (TASK_ASSIGNED template), queued mails: ' || l_cnt, l_cnt >= 1);

    session_as('REQ1');
    l_list := my_tasks('RFI_RESPONSE');
    ok('REQ1 sees it in My Tasks: ' || l_list, instr(l_list, to_char(l_task)) > 0);
    session_as('REQ2');
    ok('REQ2 does not: ' || my_tasks('RFI_RESPONSE'), instr(my_tasks('RFI_RESPONSE'), to_char(l_task)) = 0);

    session_as('REQ1');
    xxfnd_rfi_pkg.respond(l_rfi, to_clob('Attached, signed on 1 Sept.'));
    commit;
    select state_code into l_state from apex_tasks where task_id = l_task;
    ok('responding completes the RFI_RESPONSE task: ' || l_state, l_state = 'COMPLETED');
    select review_task_id into l_task from xxfnd_rfis where rfi_id = l_rfi;
    ok('and creates an RFI_REVIEW task (' || l_task || ')', l_task is not null);

    session_as('OFFICER1');
    ok('OFFICER1 sees the review: ' || my_tasks('RFI_REVIEW'), instr(my_tasks('RFI_REVIEW'), to_char(l_task)) > 0);
    xxfnd_rfi_pkg.resolve(l_rfi, 'RESOLVED', 'Complete.');
    commit;
    select state_code into l_state from apex_tasks where task_id = l_task;
    ok('resolving completes the RFI_REVIEW task: ' || l_state, l_state = 'COMPLETED');

    ------------------------------------------------------------ delegation
    insert into xxfnd_wf_delegations (delegator_user_name, delegate_user_name, start_date, end_date, reason)
    values ('REQ1', 'REQ2', trunc(sysdate), trunc(sysdate) + 7, 'Annual leave');
    xxfnd_rfi_pkg.create_rfi('XXCMP_PARTIES', to_char(l_party), 'USER', l_cat,
                             'Second request while REQ1 is away.', 'Y', trunc(sysdate) + 5,
                             p_recipient_user_name => 'REQ1', p_application_code => 'KYC', p_rfi_id => l_rfi2, p_token => l_token);
    commit;
    select response_task_id into l_task from xxfnd_rfis where rfi_id = l_rfi2;
    select listagg(participant, ',') within group (order by participant) into l_list
      from apex_task_participants where task_id = l_task and participant_type = 'POTENTIAL_OWNER';
    ok('delegation REQ1 -> REQ2 adds REQ2 as owner: ' || l_list, l_list = 'REQ1,REQ2');
    session_as('REQ2');
    select count(*) into l_cnt from xxfnd_rfis where rfi_id = l_rfi2;
    ok('the delegate REQ2 can see the delegated RFI (data security)', l_cnt = 1);
    ok('and has the task in My Tasks: ' || my_tasks('RFI_RESPONSE'), instr(my_tasks('RFI_RESPONSE'), to_char(l_task)) > 0);
    session_as('OFFICER1');
    xxfnd_rfi_pkg.resolve(l_rfi2, 'CANCELLED', 'Test cleanup.');
    commit;
    select state_code into l_state from apex_tasks where task_id = l_task;
    ok('cancelling the RFI cancels its task: ' || l_state, l_state = 'CANCELED' or l_state = 'CANCELLED');
    delete from xxfnd_wf_delegations;
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

    session_as('HOC1');
    ok('HOC1 sees it in My Tasks: ' || my_tasks('CONFIG_CHANGE'), instr(my_tasks('CONFIG_CHANGE'), to_char(l_task)) > 0);
    ok('HOC1 may claim it', apex_human_task.is_allowed(p_task_id => l_task, p_operation => apex_human_task.c_task_op_claim));
    apex_human_task.approve_task(p_task_id => l_task, p_autoclaim => true);
    commit;
    select approval_status || '/' || approved_by into l_list from xxcmp_attachment_rules where attachment_rule_id = l_rule;
    ok('HOC1 approves -> rule ' || l_list, l_list = 'APPROVED/HOC1');

    ------------------------------------------------------------ deadlines
    session_as('OFFICER1');
    update xxfnd_task_settings set reminder_days_before = 30 where task_definition = 'RFI_RESPONSE';
    xxfnd_rfi_pkg.create_rfi('XXCMP_PARTIES', to_char(l_party), 'USER', l_cat,
                             'Deadline test.', 'Y', trunc(sysdate) + 5,
                             p_recipient_user_name => 'REQ1', p_application_code => 'KYC', p_rfi_id => l_rfi2, p_token => l_token);
    select response_task_id into l_task from xxfnd_rfis where rfi_id = l_rfi2;
    xxfnd_task_pkg.process_deadlines;
    xxfnd_task_pkg.process_deadlines;   -- second run must not send again
    select count(*) into l_cnt from xxfnd_task_alerts where task_id = l_task and alert_type = 'REMINDER';
    ok('reminder recorded once for the new task', l_cnt = 1);
    select count(*) into l_cnt from apex_mail_queue where mail_subj like 'Reminder:%';
    ok('reminder e-mail queued: ' || l_cnt, l_cnt >= 1);
    update xxfnd_task_settings set reminder_days_before = 2 where task_definition = 'RFI_RESPONSE';
    xxfnd_rfi_pkg.resolve(l_rfi2, 'CANCELLED', 'Test cleanup.');
    commit;
    apex_session.delete_session;
end;
/
exit
