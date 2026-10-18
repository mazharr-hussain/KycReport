-- Release 76 A-11 (KYC, run as XXCUS): approval rules from the Approval Setup. No matching rule stops the submit with
-- its message; a step whose role no active user holds stops the submit with its message (no workflow that faults later);
-- the usual rule sends the request to its approver; a rule without steps approves at once (request: case opened on
-- submit; case: APPROVAL_REQUIRED = N, auto-approved); background work shows as "System", not "nobody".
-- A successful submit starts a workflow, which commits: the test never changes the existing rules - it adds its own
-- "no approval" rules and removes them (and switches the roles it switched off back on) at the end, also on an error.
-- Needs security_test.sql and workflow_test.sql first (REQ1 and the Compliance roles).
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_req   number;
    l_case  number;
    l_txt   varchar2(4000);
    l_n     number;
    l_r     xxcmp_requests%rowtype;
    c_name  constant varchar2(30) := 'R76 test - no approval';

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    procedure answer(p_q varchar2, p_label varchar2) is
    begin
        update xxcmp_request_answers a
           set answer_option_id = (select o.answer_option_id from xxcmp_answer_options o
                                    where o.question_id = a.question_id and o.answer_label = p_label)
         where a.request_id = l_req and a.respondent_type = 'REQUESTER'
           and a.question_id = (select q.question_id from xxcmp_questions q
                                 where q.questionnaire_code = 'CORPORATE' and q.question_text like '%' || p_q || '%');
    end;
    -- a request of REQ1 that needs KYC, ready to submit
    procedure new_request is
    begin
        l_req := null;
        xxcmp_request_pkg.save_request(l_req, 'NEW', null, 'ORGANIZATION', dbms_random.string('U', 16), 'AE',
                   'R76' || to_char(systimestamp, 'HH24MISSFF3'), 'LLC', null,
                   'contact@example.com', '+971 4 000 0000', null, null, 'PROCUREMENT', 'Release 76 approval rules test',
                   p_registration_type => 'COMMERCIAL_REGISTRATION', p_business_relationship => 'VENDOR');
        answer('regulated stock exchange', 'No');
        answer('country of incorporation', 'Medium-risk jurisdiction');
        answer('transaction volume', 'Above 10 million');
        answer('politically exposed', 'No');
        answer('cash-intensive', 'Yes');
    end;
    -- the submit runs as the requester (REQ1, with REQ1's data security); the error message, or null
    function submit_message return varchar2 is
    begin
        savepoint before_submit;
        xxfnd_vpd_pkg.end_trusted;
        xxcmp_request_pkg.submit(l_req);
        xxfnd_vpd_pkg.begin_trusted;
        return null;
    exception when others then
        rollback to before_submit;
        xxfnd_vpd_pkg.begin_trusted;
        return sqlcode || ' ' || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+');
    end;
    -- a rule without steps that is more specific than the configured rules (it wins while it exists)
    -- release 93: COMMON's routines and the test helper (common_test_fixtures.sql, COMMON C14), no direct writes
    procedure no_approval_rule(p_type varchar2, p_conds apex_t_varchar2) is
    begin
        xxfnd_approval_rule_pkg.register_rule('KYC', p_type, c_name, null, p_conds, 1);
    end;
    procedure cleanup is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        for t in (select approval_type_code from xxfnd_approval_rules where rule_name = c_name) loop
            xxfnd_approval_rule_pkg.unregister_rule('KYC', t.approval_type_code, c_name);
        end loop;
        xxfusion.xxfnd_test_fixture_pkg.set_rules_enabled('KYC_REQUEST', 'Y');
        xxfusion.xxfnd_test_fixture_pkg.set_role_enabled('COMPLIANCE_OFFICER', 'Y');
        xxfusion.xxfnd_test_fixture_pkg.set_role_enabled('COMPLIANCE_MANAGER', 'Y');
        commit;
        xxfnd_vpd_pkg.end_trusted;
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'REQ1');
    xxfnd_vpd_pkg.begin_trusted;

    ok('background work shows as System: ' || xxfnd_ui_pkg.person_name('nobody'), xxfnd_ui_pkg.person_name('nobody') = 'System');

    -- 1. no matching rule: the submit stops with the message (nothing is committed)
    new_request;
    xxfusion.xxfnd_test_fixture_pkg.set_rules_enabled('KYC_REQUEST', 'N');
    l_txt := submit_message;
    ok('no matching rule stops the submit: ' || l_txt, l_txt like '-20531 No approval rule applies%');
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('the request stays a draft: ' || l_r.request_status, l_r.request_status = 'DRAFT');
    xxfusion.xxfnd_test_fixture_pkg.set_rules_enabled('KYC_REQUEST', 'Y');

    -- 2. a step nobody can approve (no active Compliance officer): the submit stops with the message
    xxfusion.xxfnd_test_fixture_pkg.set_role_enabled('COMPLIANCE_OFFICER', 'N');
    ok('nobody holds the Compliance officer role now', xxfnd_workflow_pkg.users_in_role('COMPLIANCE_OFFICER') is null);
    l_txt := submit_message;
    ok('a step without an approver stops the submit: ' || l_txt, l_txt like '-20535 The approval step "%" has no approver%');
    select count(*) into l_n from xxfnd_approval_txns where approval_type_code = 'KYC_REQUEST' and txn_id = to_char(l_req);
    ok('no approval was started', l_n = 0);
    xxfusion.xxfnd_test_fixture_pkg.set_role_enabled('COMPLIANCE_OFFICER', 'Y');

    -- 3. the usual rule (with its step): the request goes to its approver through the workflow
    l_txt := submit_message;
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('a rule with steps: the request waits for its approver' || nvl2(l_txt, ': ' || l_txt, null),
       l_txt is null and l_r.request_status = 'IN_PROGRESS' and l_r.workflow_id is not null and l_r.auto_approved_date is null);

    -- 4. a rule without steps: approved at once, the case is opened on submit
    no_approval_rule('KYC_REQUEST', apex_t_varchar2('PARTY_TYPE=ORGANIZATION', 'JURISDICTION=AE'));
    new_request;
    l_txt := submit_message;
    ok('a rule without steps lets the submit through' || nvl2(l_txt, ': ' || l_txt, null), l_txt is null);
    select * into l_r from xxcmp_requests where request_id = l_req;
    select max(case_id) into l_case from xxcmp_cases where request_id = l_req;
    ok('the request is approved at once and its case opened: ' || l_r.request_status || ', case ' || l_case,
       l_r.request_status = 'APPROVED' and l_r.auto_approved_date is not null and l_case is not null);
    ok('no request workflow was started', l_r.workflow_id is null);

    -- 5. case: the KYC_CASE workflow (1.3) skips the approvers when the matching rule has no steps
    update xxcmp_cases set risk_tier = 'LOW' where case_id = l_case;
    xxcmp_case_pkg.start_approval(l_case);
    ok('a case rule with steps: approval required = ' || xxcmp_case_pkg.approval_required(l_case),
       xxcmp_case_pkg.approval_required(l_case) = 'Y');
    update xxcmp_cases set case_status = 'INVESTIGATION' where case_id = l_case;
    no_approval_rule('KYC_CASE', apex_t_varchar2('RISK_TIER=LOW', 'ENHANCED_KYC=N'));
    xxcmp_case_pkg.start_approval(l_case);
    select count(*) into l_n from xxcmp_cases where case_id = l_case and auto_approved_date is not null;
    ok('a case rule without steps: approval required = ' || xxcmp_case_pkg.approval_required(l_case) || ', auto-approved',
       xxcmp_case_pkg.approval_required(l_case) = 'N' and l_n = 1);

    -- 6. case submit: a level nobody can approve is refused on Submit
    xxfusion.xxfnd_test_fixture_pkg.set_role_enabled('COMPLIANCE_MANAGER', 'N');
    l_txt := xxfnd_approval_rule_pkg.approval_error('KYC_CASE', apex_t_varchar2('RISK_TIER=HIGH', 'ENHANCED_KYC=N'));
    ok('case approval: a level without an approver gives its message: ' || l_txt, l_txt like 'The approval step "%" has no approver%');
    xxfusion.xxfnd_test_fixture_pkg.set_role_enabled('COMPLIANCE_MANAGER', 'Y');
    ok('case approval: no message when every level has an approver',
       xxfnd_approval_rule_pkg.approval_error('KYC_CASE', apex_t_varchar2('RISK_TIER=HIGH', 'ENHANCED_KYC=N')) is null);

    xxfnd_vpd_pkg.end_trusted;
    rollback;
    cleanup;
    apex_session.delete_session;
exception
    when others then
        rollback;
        cleanup;
        raise;
end;
/
exit
