-- KYC 105 (request stages, stage 1 Assign): the requesting country is required; no duplicate check on the request form;
-- the request follows its case (Under Review, In Approval, Information Needed, Approved / Rejected); the submit message;
-- Assign is refused for a task that is not the request's. Everything is rolled back.
-- Needs security_test.sql (REQ1).
set serveroutput on size unlimited feedback off
declare
    l_app number;
    l_tag varchar2(20) := dbms_random.string('U', 10);
    l_a   number;
    l_b   number;
    l_txt varchar2(4000);
    l_st  varchar2(30);

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function rule(p_country varchar2) return varchar2 is
    begin
        return xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'R105 ' || l_tag, 'AE', 'CR-' || l_tag,
                                               'PRIVATE_COMPANY', null, null, null, null,
                                               p_registration_type => 'COMMERCIAL_REGISTRATION',
                                               p_business_relationship => 'VENDOR', p_requesting_country => p_country);
    end rule;
    function status(p_id number) return varchar2 is
        l varchar2(30);
    begin
        select request_status into l from xxcmp_requests where request_id = p_id;
        return l;
    end status;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 201, 'REQ1');

    l_txt := rule(null);
    ok('the requesting country is required: ' || l_txt, l_txt = 'Choose the requesting country.');
    ok('with a country the request is accepted', rule('QA') is null);

    -- two requests for the same counterparty: no duplicate check (Compliance decides on the match)
    xxcmp_request_pkg.save_request(l_a, 'NEW', null, 'ORGANIZATION', 'R105 ' || l_tag, 'AE', 'CR-' || l_tag,
                                   'PRIVATE_COMPANY', null, null, null, null, null, null, null, p_draft => 'Y',
                                   p_registration_type => 'COMMERCIAL_REGISTRATION', p_requesting_country => 'QA');
    xxcmp_request_pkg.save_request(l_b, 'NEW', null, 'ORGANIZATION', 'R105 ' || l_tag, 'AE', 'CR-' || l_tag,
                                   'PRIVATE_COMPANY', null, null, null, null, null, null, null, p_draft => 'Y',
                                   p_registration_type => 'COMMERCIAL_REGISTRATION', p_requesting_country => 'QA');
    ok('a second request for the same registration is saved', l_b is not null and l_b <> l_a);
    select requesting_country into l_st from xxcmp_requests where request_id = l_a;
    ok('the requesting country is stored', l_st = 'QA');
    ok('a new request is Draft', status(l_a) = 'DRAFT');

    -- the request follows its case
    xxcmp_request_pkg.case_changed(l_a, 'INVESTIGATION');
    ok('case under investigation = Under Review', status(l_a) = 'UNDER_REVIEW');
    xxcmp_request_pkg.case_changed(l_a, 'PENDING_APPROVAL');
    ok('case submitted for approval = In Approval', status(l_a) = 'IN_APPROVAL');
    xxcmp_request_pkg.case_changed(l_a, 'PENDING_INFORMATION');
    ok('case question = Information Needed', status(l_a) = 'INFO_NEEDED');
    xxcmp_request_pkg.case_changed(l_a, 'APPROVED');
    ok('case approved = Approved', status(l_a) = 'APPROVED');
    xxcmp_request_pkg.case_changed(l_b, 'REJECTED');
    ok('case rejected = Rejected', status(l_b) = 'REJECTED');

    -- KYC not required closes the request
    xxcmp_request_pkg.close_without_case(l_b);
    ok('KYC not required = KYC Not Required', status(l_b) = 'NOT_REQUIRED');
    ok('the not-required message', xxcmp_request_pkg.submit_message(l_b) = 'KYC is not needed. Kindly proceed.');
    ok('the required message', xxcmp_request_pkg.submit_message(l_a) = 'The request is submitted for KYC report.');
    ok('status tones', xxcmp_request_pkg.status_tone('UNDER_REVIEW') = 'info' and xxcmp_request_pkg.status_tone('NOT_REQUIRED') = 'success');

    -- Assign is refused for a task that is not the request's checklist task
    begin
        xxcmp_request_pkg.assign_request(l_a, -1, 'REQ1');
        ok('assign with a foreign task is refused', false);
    exception
        when others then
            ok('assign with a foreign task is refused: ' || sqlerrm, true);
    end;
    ok('bulk assign without tasks assigns nothing', xxcmp_request_pkg.assign_requests(l_a || ':' || l_b, 'REQ1') = 0);
    rollback;
    apex_session.delete_session;
exception
    when others then
        rollback;
        dbms_output.put_line('FAIL ' || sqlerrm);
end;
/
