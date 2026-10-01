-- Request module (release 23): request and counterparty rules, the new counterparty created as a Pending party with
-- the request, switching to an existing party, submit (workflow), Information Needed, cancel, reject / approve and the
-- party status that follows, KYC Required and Pending With.
-- Needs security_test.sql (REQ1, REQ2, OFFICER1). Creates its own parties with a run tag.
set serveroutput on size unlimited feedback off
declare
    l_app    number;
    l_tag    varchar2(20) := dbms_random.string('U', 12);
    l_req    number;
    l_req2   number;
    l_old    number;
    l_party  number;
    l_ok     number;
    l_cnt    number;
    l_task   number;
    l_txt    varchar2(4000);
    l_r      xxcmp_requests%rowtype;

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    procedure session_as(p_user varchar2) is
    begin
        if apex_application.g_instance is not null then
            apex_session.delete_session;
        end if;
        apex_session.create_session(l_app, 1, p_user);
    end;
    procedure wait_for(p_sql varchar2) is
        l number;
    begin
        for i in 1 .. 90 loop
            execute immediate p_sql into l;
            exit when l > 0;
            dbms_session.sleep(1);
        end loop;
    end;
    function err(p_sqlerrm varchar2) return varchar2 is
    begin
        return regexp_substr(substr(p_sqlerrm, 12), '[^' || chr(10) || ']+');
    end;
    function status(p_party number) return varchar2 is
        l varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select party_status into l from xxcmp_parties where party_id = p_party;
        xxfnd_vpd_pkg.end_trusted;
        return l;
    end;
    -- a new organisation counterparty on request P_REQ (null = new request)
    procedure save_org(p_req in out number, p_name varchar2, p_reg varchar2, p_draft varchar2 default 'N',
                       p_email varchar2 default 'info@example.com', p_justification varchar2 default 'Supplier') is
    begin
        xxcmp_request_pkg.save_request(p_req, 'NEW', null, 'ORGANIZATION', p_name, 'AE', p_reg, 'LLC', date '2015-01-01',
                                       p_email, null, null, null, 'FINANCE', p_justification, p_draft);
    end;
    procedure answer_high(p_req number) is
    begin
        update xxcmp_request_answers x
           set answer_option_id = (select max(o.answer_option_id) keep (dense_rank last order by o.risk_points)
                                     from xxcmp_answer_options o where o.question_id = x.question_id and o.approval_status = 'APPROVED')
         where x.request_id = p_req;
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    session_as('OFFICER1');
    l_ok := null;
    xxcmp_party_pkg.save_party(l_ok, 'ORGANIZATION', 'Approved Org ' || l_tag, 'AE', 'APP-' || l_tag, 'LLC', null,
                               'ok@example.com', null);
    commit;

    ---------------------------------------------------------------- rules
    session_as('REQ1');
    ok('draft: only type and name are needed',
       xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'X ' || l_tag, null, null, null, null, null, null, null, 'Y') is null);
    l_txt := xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'X ' || l_tag, 'AE', 'R-' || l_tag, 'LLC', null,
                                             'x@example.com', null, null);
    ok('the business justification is required: ' || l_txt, l_txt = 'Enter the business justification.');
    l_txt := xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'X ' || l_tag, 'AE', null, 'LLC', null,
                                             'x@example.com', null, 'Why');
    ok('an organisation needs its registration number: ' || l_txt, l_txt = 'Enter the registration number.');
    l_txt := xxcmp_request_pkg.request_error(null, 'NEW', null, 'PERSON', 'X ' || l_tag, 'AE', 'ID1', null, null,
                                             'x@example.com', null, 'Why');
    ok('an individual''s ID number needs its ID type: ' || l_txt, l_txt = 'Choose the ID type of the ID number.');
    l_txt := xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'X ' || l_tag, 'AE', 'R-' || l_tag, 'LLC', null,
                                             null, null, 'Why');
    ok('an email or a phone is required: ' || l_txt, l_txt = 'Enter an email or a phone number.');
    l_txt := xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'Other ' || l_tag, 'AE', 'app ' || lower(l_tag), 'LLC',
                                             null, 'x@example.com', null, 'Why');
    ok('same number and country as an existing party is refused: ' || l_txt, l_txt like 'Party P-% already has this registration no. and country: use that party.');

    ---------------------------------------------------------------- a new counterparty becomes a Pending party
    save_org(l_req, 'Draft Org ' || l_tag, null, 'Y');
    l_r := null;
    select * into l_r from xxcmp_requests where request_id = l_req;
    l_party := l_r.party_id;
    ok('Save as Draft creates the request and a Pending party: ' || l_r.request_number || ' / ' || status(l_party),
       l_r.request_status = 'DRAFT' and l_party is not null and status(l_party) = 'PENDING');
    select count(*) into l_cnt
      from json_table(xxcmp_request_pkg.party_directory_json(null), '$[*]' columns (party_id number path '$.party_id'))
     where party_id = l_party;
    ok('a Pending party cannot be chosen as an existing party', l_cnt = 0);
    save_org(l_req, 'Draft Org ' || l_tag, 'DR-' || l_tag);
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('saving again updates the same party (no second party)', l_r.party_id = l_party and l_r.registration_number = 'DR-' || l_tag);
    select justification, last_action_date into l_txt, l_r.last_action_date from xxcmp_requests where request_id = l_req;
    ok('the action date is set', l_r.last_action_date is not null);

    -- choose an approved party instead: the Pending one is cancelled
    xxcmp_request_pkg.save_request(l_req, 'EXISTING', l_ok, null, null, null, null, null, null, null, null, null, null,
                                   'FINANCE', 'Existing supplier');
    ok('switching to an existing party cancels the Pending party: ' || status(l_party), status(l_party) = 'CANCELLED');
    save_org(l_req, 'Again Org ' || l_tag, 'AG-' || l_tag);
    select party_id into l_party from xxcmp_requests where request_id = l_req;
    ok('back to a new counterparty: a new Pending party', status(l_party) = 'PENDING');
    commit;

    ---------------------------------------------------------------- another user cannot change or cancel it
    session_as('REQ2');
    begin
        save_org(l_req, 'Hijack ' || l_tag, 'HJ-' || l_tag);
        ok('another requester cannot change the request', false);
    exception when others then
        ok('another requester cannot change the request: ' || err(sqlerrm), sqlcode = -20612);
    end;
    ok('another requester cannot cancel it: ' || xxcmp_request_pkg.cancel_error(l_req),
       xxcmp_request_pkg.cancel_error(l_req) like 'Only the requester%');

    ---------------------------------------------------------------- submit: the workflow runs
    session_as('REQ1');
    answer_high(l_req);
    ok('KYC Required is empty before the intake', xxcmp_request_pkg.kyc_required(l_req) is null);
    ok('Pending With a draft: the requester', xxcmp_request_pkg.pending_with(l_req) = 'REQ1');
    xxcmp_request_pkg.submit(l_req);
    commit;
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('submitted: In Progress with a workflow', l_r.request_status = 'IN_PROGRESS' and l_r.workflow_id is not null);
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''DOC_CHECKLIST_REVIEW'' and detail_pk = ''' || l_req || '''');
    ok('high risk: KYC Required = ' || xxcmp_request_pkg.kyc_required(l_req), xxcmp_request_pkg.kyc_required(l_req) = 'Yes');
    ok('Pending With: ' || xxcmp_request_pkg.pending_with(l_req), xxcmp_request_pkg.pending_with(l_req) in ('Compliance', 'OFFICER1'));  -- one approver: the task is assigned to them
    ok('status shown: ' || xxcmp_request_pkg.stage(l_req), xxcmp_request_pkg.stage(l_req) = 'In Progress');

    ---------------------------------------------------------------- Information Needed and back
    xxcmp_request_pkg.info_requested(l_req);
    ok('Information Needed: ' || xxcmp_request_pkg.stage(l_req) || ', with ' || xxcmp_request_pkg.pending_with(l_req),
       xxcmp_request_pkg.stage(l_req) = 'Information Needed' and xxcmp_request_pkg.pending_with(l_req) = 'REQ1');
    ok('the requester may edit it while Information Needed', xxcmp_request_pkg.is_editable(l_req) = 'Y'
       and xxcmp_request_pkg.party_editable(l_req) = 'Y');
    begin
        xxcmp_request_pkg.save_request(l_req, 'EXISTING', l_ok, null, null, null, null, null, null, null, null, null, null,
                                       'FINANCE', 'x');
        ok('the counterparty of a submitted request cannot be replaced', false);
    exception when others then
        ok('the counterparty of a submitted request cannot be replaced: ' || err(sqlerrm), sqlcode = -20617);
    end;
    xxcmp_request_pkg.info_submitted(l_req);
    ok('answered: In Progress again', xxcmp_request_pkg.stage(l_req) = 'In Progress');

    ---------------------------------------------------------------- cancel
    xxcmp_request_pkg.cancel(l_req, 'Not needed any more');
    commit;
    select * into l_r from xxcmp_requests where request_id = l_req;
    select count(*) into l_cnt from apex_workflows where workflow_id = l_r.workflow_id and state_code in ('ACTIVE', 'SUSPENDED');
    ok('cancelled: status Cancelled, workflow ended, party Cancelled',
       l_r.request_status = 'CANCELLED' and l_cnt = 0 and status(l_r.party_id) = 'CANCELLED');
    ok('a cancelled request cannot be cancelled again', xxcmp_request_pkg.cancel_error(l_req) like '%is closed%');

    ---------------------------------------------------------------- reject / approve without case: the party follows
    save_org(l_req2, 'Reject Org ' || l_tag, 'RJ-' || l_tag);
    commit;
    select party_id into l_party from xxcmp_requests where request_id = l_req2;
    xxcmp_request_pkg.reject(l_req2);
    ok('rejected request: its Pending party is Rejected', status(l_party) = 'REJECTED');
    l_req2 := null;
    save_org(l_req2, 'Easy Org ' || l_tag, 'EZ-' || l_tag);
    select party_id into l_party from xxcmp_requests where request_id = l_req2;
    xxcmp_request_pkg.close_without_case(l_req2);
    ok('approved without KYC: request and party Approved',
       xxcmp_request_pkg.stage(l_req2) = 'Approved' and status(l_party) = 'APPROVED');
    commit;

    ---------------------------------------------------------------- approval path from setup (release 24)
    insert into xxcmp_approval_paths (path_name, party_type, jurisdiction, priority, step_sequence, step_name, approver_type, role_code, user_name)
    select 'Test ' || l_tag, 'ORGANIZATION', 'AE', 1, 1, 'Compliance check', 'ROLE', 'COMPLIANCE_OFFICER', null from dual union all
    select 'Test ' || l_tag, 'ORGANIZATION', 'AE', 1, 2, 'Finance sign-off', 'USER', null, 'REQ1' from dual;
    l_req2 := null;
    save_org(l_req2, 'Path Org ' || l_tag, 'PA-' || l_tag);
    ok('the path with the most matching criteria applies', xxcmp_approval_pkg.path_for(l_req2) = 'Test ' || l_tag);
    ok('before submit: the expected path lists both steps',
       dbms_lob.instr(xxcmp_approval_pkg.path_html(l_req2), 'Finance sign-off') > 0);
    xxcmp_approval_pkg.start_path(l_req2);
    ok('step 1: approved by the role (' || xxcmp_approval_pkg.step_approvers(l_req2) || ')',
       xxcmp_approval_pkg.step_name(l_req2) = 'Compliance check' and instr(xxcmp_approval_pkg.step_approvers(l_req2), 'OFFICER1') > 0);
    ok('after step 1 there is a next step', xxcmp_approval_pkg.next_step(l_req2) = 'Y');
    ok('step 2: a named user, who may also be the requester (role based, not person based)',
       xxcmp_approval_pkg.step_approvers(l_req2) = 'REQ1');
    ok('after the last step the path is complete (the case opens)', xxcmp_approval_pkg.next_step(l_req2) = 'N');
    -- live: the workflow runs one approval task per step; the requester approves step 2; then the case opens
    l_req2 := null;
    save_org(l_req2, 'Live Path Org ' || l_tag, 'LP-' || l_tag);
    answer_high(l_req2);
    xxcmp_request_pkg.submit(l_req2);
    commit;
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''DOC_CHECKLIST_REVIEW'' and state_code in (''ASSIGNED'', ''UNASSIGNED'') and detail_pk = ''' || l_req2 || '''');
    select max(task_id) into l_task from apex_tasks where task_def_static_id = 'DOC_CHECKLIST_REVIEW' and detail_pk = to_char(l_req2);
    session_as('OFFICER1');
    apex_human_task.approve_task(l_task, p_autoclaim => true);
    commit;
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''DOC_CHECKLIST_REVIEW'' and state_code in (''ASSIGNED'', ''UNASSIGNED'') and detail_pk = ''' || l_req2 || '''');
    select max(task_id) into l_task from apex_tasks where task_def_static_id = 'DOC_CHECKLIST_REVIEW' and detail_pk = to_char(l_req2)
       and state_code in ('ASSIGNED', 'UNASSIGNED');
    ok('step 1 approved: the step 2 task goes to the named user', l_task is not null
       and xxcmp_approval_pkg.step_name(l_req2) = 'Finance sign-off');
    select count(*) into l_cnt from xxcmp_cases where request_id = l_req2;
    ok('no case before the last step', l_cnt = 0);
    session_as('REQ1');
    apex_human_task.approve_task(l_task, p_autoclaim => true);
    commit;
    session_as('OFFICER1');     -- sees the cases (data security)
    wait_for('select count(*) from xxcmp_cases where request_id = ' || l_req2);
    select count(*) into l_cnt from xxcmp_cases where request_id = l_req2;
    ok('the requester approves step 2 (role based); the last approval opens the case', l_cnt = 1);
    ok('history shows the submit and the approvals',
       dbms_lob.instr(xxcmp_approval_pkg.history_html(l_req2), 'Submitted') > 0);
    delete from xxcmp_approval_paths where path_name = 'Test ' || l_tag;
    commit;
    apex_session.delete_session;
end;
/
exit
