-- Release 74 (KYC, run as XXCUS): common error handling, common workflow runtime, common RFI workflow with its loop.
-- Uses an open case and a requester (REQ1, see security_test.sql); everything is rolled back.
-- Release 89: the RFI runs in COMMON's workflow RFI, whose tasks the workflow engine creates in the background after a
-- commit; this test rolls back, so it checks the workflow and the RFI data (the tasks: kyc89_rfi_test.sql).
set serveroutput on size unlimited feedback off
declare
    l_app    number;
    l_case   number;
    l_rfi    number;
    l_token  varchar2(64);
    l_n      number;
    l_status varchar2(30);
    l_cid    number;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';

    -- error handling
    ok('catalogue message with a value',
       xxfnd_error_pkg.message('XXFND_UNEXPECTED_ERROR', apex_t_varchar2('42')) like '%reference 42%');
    begin
        xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        ok('raise_error raises', false);
    exception when others then
        ok('raise_error raises its number (' || sqlcode || ')', sqlcode = -20002);
    end;
    l_n := xxfnd_error_pkg.log_error('r74_kyc_test', 'test entry');
    ok('an error is logged with a reference (' || l_n || ')', l_n > 0);

    -- common workflow runtime
    ok('state of an unknown workflow is empty', xxfnd_workflow_pkg.state(-1) is null);
    ok('an unknown workflow is not running', xxfnd_workflow_pkg.is_running(-1) = 'N');

    -- RFI loop: raised from a case to a user, answered, asked again, answered, resolved
    apex_session.create_session(l_app, 1, 'OFFICER1');
    xxfnd_vpd_pkg.begin_trusted;
    select max(case_id) into l_case from xxcmp_cases where case_status = 'INVESTIGATION';
    xxcmp_case_pkg.raise_rfi('XXCMP_CASES', to_char(l_case), 'REQUESTING_DEPARTMENT', 'REQ1', null,
                             'CLARIFICATION', 'Please confirm the trade licence number', 'N', null);
    select max(rfi_id) into l_rfi from xxfnd_rfis where entity_name = 'XXCMP_CASES' and pk1_value = to_char(l_case);
    select count(*) into l_n from xxfnd_rfis r join apex_workflows w on w.workflow_id = r.workflow_id
     where r.rfi_id = l_rfi and w.application_id = xxfnd_workflow_pkg.common_application_id;
    ok('raised from the case: common RFI in COMMON''s workflow RFI', l_rfi is not null and l_n = 1);
    ok('a pausing RFI blocks the case submit', xxcmp_case_pkg.submit_error(l_case) like '%request for information%'
                                              or xxfnd_rfi_pkg.open_count('XXCMP_CASES', to_char(l_case)) > 0);
    xxfnd_vpd_pkg.end_trusted;

    apex_session.create_session(l_app, 1, 'REQ1');
    xxfnd_rfi_pkg.respond(l_rfi, 'The number is 12345');
    select rfi_status into l_status from xxfnd_rfis where rfi_id = l_rfi;
    ok('answered: waiting for review (' || l_status || ')', l_status = 'RESPONDED');

    apex_session.create_session(l_app, 1, 'OFFICER1');
    l_token := xxfnd_rfi_pkg.ask_again(l_rfi, 'Please attach the licence copy too');
    select rfi_status, round_no into l_status, l_n from xxfnd_rfis where rfi_id = l_rfi;
    ok('asked again: same RFI, round 2, waiting again', l_status = 'WAITING_FOR_INFORMATION' and l_n = 2 and l_token is null);

    apex_session.create_session(l_app, 1, 'REQ1');
    xxfnd_rfi_pkg.respond(l_rfi, 'Attached');
    apex_session.create_session(l_app, 1, 'OFFICER1');
    xxfnd_rfi_pkg.resolve(l_rfi, 'RESOLVED', 'Complete');
    select count(*) into l_n from xxfnd_rfi_rounds where rfi_id = l_rfi and response_text is not null;
    ok('two rounds answered, then resolved', l_n = 2
       and xxfnd_rfi_pkg.open_count('XXCMP_CASES', to_char(l_case)) = 0);
    select count(*) into l_n from xxfnd_rfi_rounds where rfi_id = l_rfi and review_outcome = 'ASKED_AGAIN';
    ok('round 1 recorded as asked again', l_n = 1);

    -- external person: answers through the one-time link
    xxfnd_vpd_pkg.begin_trusted;
    select max(c.party_contact_id) into l_cid from xxcmp_party_contacts c where c.email is not null;
    xxfnd_vpd_pkg.end_trusted;
    if l_cid is null then
        dbms_output.put_line('SKIP no contact person with an e-mail');
    else
        xxfnd_rfi_pkg.create_rfi('XXCMP_CASES', to_char(l_case), 'EXTERNAL', 'CLARIFICATION', 'Send the audited accounts',
                                 p_recipient_email => 'x@example.com', p_recipient_name => 'Test Contact',
                                 p_recipient_reference => to_char(l_cid), p_application_code => 'KYC',
                                 p_rfi_id => l_rfi, p_token => l_token);
        ok('external RFI gets a one-time token', l_token is not null);
        ok('the link answers it', xxfnd_rfi_pkg.respond_by_token(l_token, 'Sent') = l_rfi);
        begin
            l_n := xxfnd_rfi_pkg.respond_by_token(l_token, 'again');
            ok('the link works only once', false);
        exception when others then
            ok('the link works only once', sqlcode = -20504);
        end;
    end if;

    -- earlier KYC RFIs were copied with their numbers; XXCMP_RFIS unchanged
    xxfnd_vpd_pkg.begin_trusted;
    select count(*) into l_n from xxcmp_rfis r
     where not exists (select 1 from xxfnd_rfis f where f.rfi_id = r.rfi_id and f.rfi_number = r.rfi_number);
    xxfnd_vpd_pkg.end_trusted;
    ok('every earlier RFI is in the common table with its number', l_n = 0);
    rollback;

    -- Approval Setup (AME style): request and case approvers from rules, ad-hoc approver
    declare
        l_req   number;
        l_names varchar2(4000);
        l_lv    number;
        l_tier  varchar2(30);
    begin
        apex_session.create_session(l_app, 1, 'OFFICER1');
        xxfnd_vpd_pkg.begin_trusted;
        -- release 76 (T-01): the newest request whose approval is in progress (not just any request In Progress)
        select max(r.request_id) into l_req from xxcmp_requests r
         where r.request_status = 'IN_PROGRESS'
           and xxfnd_approval_rule_pkg.is_started('KYC_REQUEST', to_char(r.request_id)) = 'Y';
        ok('request approvers come from the Approval Setup',
           xxfnd_approval_rule_pkg.is_started('KYC_REQUEST', to_char(l_req)) = 'Y'
           and xxcmp_approval_pkg.step_approvers(l_req) = xxfnd_approval_rule_pkg.current_approvers('KYC_REQUEST', to_char(l_req)));
        select max(case_id) keep (dense_rank last order by case_id), max(risk_tier) keep (dense_rank last order by case_id)
          into l_case, l_tier from xxcmp_cases where case_status = 'INVESTIGATION' and risk_tier is not null;
        if l_case is null then
            dbms_output.put_line('SKIP no case with a risk tier under investigation');
        else
            l_lv := xxcmp_case_pkg.required_levels(l_case);
            ok('case levels from the matching rule (' || l_lv || ' for tier ' || l_tier || ')', l_lv >= 1);
            xxcmp_case_pkg.start_approval(l_case);
            xxfnd_approval_rule_pkg.add_approver('KYC_CASE', to_char(l_case), 'ROLE', 'HEAD_OF_COMPLIANCE',
                                                 p_comment => 'Large exposure', p_force => 'Y');
            ok('an ad-hoc approver adds a level (' || l_lv || ' -> ' || xxcmp_case_pkg.required_levels(l_case) || ')',
               xxcmp_case_pkg.required_levels(l_case) = l_lv + 1);
            select count(*) into l_n from table(xxfnd_approval_rule_pkg.steps('KYC_CASE', to_char(l_case)))
             where source = 'ADHOC' and position = 2;
            ok('added right after the current approver', l_n = 1);
            begin
                apex_session.create_session(l_app, 1, 'REQ2');
                xxfnd_approval_rule_pkg.add_approver('KYC_CASE', to_char(l_case), 'USER', p_user_name => 'REQ2');
                ok('only the requester or the current approver may add an approver', false);
            exception when others then
                ok('only the requester or the current approver may add an approver', sqlcode = -20533);
            end;
        end if;
        xxfnd_vpd_pkg.end_trusted;
        rollback;
    end;

    -- case RFI: its own process; the provider comes from the Approval Setup (CASE_RFI: the requester), ad-hoc person
    declare
        l_req  varchar2(255);
        l_rfi2 number;
        l_st   varchar2(30);
    begin
        apex_session.create_session(l_app, 1, 'OFFICER1');
        xxfnd_vpd_pkg.begin_trusted;
        select max(c.case_id) keep (dense_rank last order by c.case_id), max(q.requester_user_name) keep (dense_rank last order by c.case_id)
          into l_case, l_req
          from xxcmp_cases c join xxcmp_requests q on q.request_id = c.request_id
         where c.case_status = 'INVESTIGATION' and q.requester_user_name in ('REQ1', 'REQ2');
        xxfnd_vpd_pkg.end_trusted;
        if l_case is null then
            dbms_output.put_line('SKIP no case of REQ1 / REQ2 under investigation');
        else
            xxcmp_case_pkg.raise_rfi('XXCMP_CASES', to_char(l_case), 'SETUP', null, null, 'CLARIFICATION',
                                     'Confirm the shareholder register', 'Y', null);
            select max(rfi_id) into l_rfi2 from xxfnd_rfis where entity_name = 'XXCMP_CASES' and pk1_value = to_char(l_case);
            ok('case RFI as set up: the requester provides the information (' || xxfnd_rfi_pkg.recipient(l_rfi2) || ')',
               xxfnd_rfi_pkg.recipient(l_rfi2) = l_req);
            xxfnd_approval_rule_pkg.add_approver('CASE_RFI', to_char(l_rfi2), 'USER', p_user_name => 'OFFICER1',
                                                 p_comment => 'Also from Officer1', p_force => 'Y');
            apex_session.create_session(l_app, 1, l_req);
            xxfnd_rfi_pkg.respond(l_rfi2, 'Register attached');
            select rfi_status into l_st from xxfnd_rfis where rfi_id = l_rfi2;
            ok('after the requester, the added person answers (' || xxfnd_rfi_pkg.recipient(l_rfi2) || ', ' || l_st || ')',
               xxfnd_rfi_pkg.recipient(l_rfi2) = 'OFFICER1' and l_st = 'WAITING_FOR_INFORMATION');
            apex_session.create_session(l_app, 1, 'OFFICER1');
            xxfnd_rfi_pkg.respond(l_rfi2, 'Checked');
            select rfi_status into l_st from xxfnd_rfis where rfi_id = l_rfi2;
            -- release 89: no provider is waiting any more, so COMMON's workflow goes on to the review
            ok('then it goes to review (' || l_st || ')', l_st = 'RESPONDED' and xxfnd_rfi_pkg.is_waiting(l_rfi2) = 'N');
        end if;
        rollback;
    end;

    -- case approval: Request Information leaves the case Pending Information, Submit Information brings it back
    declare
        l_c  number;
        l_st varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(case_id) into l_c from xxcmp_cases where case_status = 'INVESTIGATION';
        update xxcmp_cases set case_status = 'PENDING_APPROVAL' where case_id = l_c;
        xxcmp_case_pkg.info_requested(l_c);
        select case_status into l_st from xxcmp_cases where case_id = l_c;
        ok('case approval: information requested - case ' || l_st, l_st = 'PENDING_INFORMATION');
        xxcmp_case_pkg.info_submitted(l_c);
        select case_status into l_st from xxcmp_cases where case_id = l_c;
        ok('case approval: information submitted - case ' || l_st, l_st = 'PENDING_APPROVAL');
        xxcmp_case_pkg.info_submitted(l_c);
        select case_status into l_st from xxcmp_cases where case_id = l_c;
        ok('submitting twice changes nothing (' || l_st || ')', l_st = 'PENDING_APPROVAL');
        select meaning into l_st from xxfnd_lookup_values where lookup_type = 'KYC_REQUEST_STATUS' and lookup_code = 'INFO_NEEDED';
        ok('request status INFO_NEEDED reads ' || l_st, l_st = 'Pending Information');
        xxfnd_vpd_pkg.end_trusted;
        rollback;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            rollback;
            raise;
    end;
end;
/
exit
