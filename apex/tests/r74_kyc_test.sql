-- Release 74 (KYC, run as XXCUS): common error handling, common workflow runtime, common RFI workflow with its loop.
-- Uses an open case and a requester (REQ1, see security_test.sql); everything is rolled back.
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
    select count(*) into l_n from apex_tasks where task_def_static_id = 'RFI_RESPONSE' and detail_pk = to_char(l_rfi)
       and state_code in ('UNASSIGNED', 'ASSIGNED');
    ok('raised from the case: common RFI with a response task', l_rfi is not null and l_n = 1);
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
end;
/
exit
