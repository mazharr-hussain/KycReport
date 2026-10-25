-- KYC 103 (Create Request in 3 steps): step 1 saves the request without a counterparty (department, party type,
-- business relationship; XXCMP_REQUEST_PKG.SAVE_INTAKE / INTAKE_ERROR); step 2 saves the justification and the
-- counterparty (SAVE_COUNTERPARTY) and keeps what step 1 saved. Everything is rolled back.
-- Needs security_test.sql (REQ1).
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_tag   varchar2(20) := dbms_random.string('U', 10);
    l_req   number;
    l_txt   varchar2(4000);
    l_r     xxcmp_requests%rowtype;

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 201, 'REQ1');

    -- step 1
    ok('the party type is required', xxcmp_request_pkg.intake_error(null, null, null) = 'Choose the party type.');
    xxcmp_request_pkg.save_intake(l_req, 'ORGANIZATION', xxcmp_request_pkg.default_department, 'VENDOR');
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('step 1 creates a Draft request without a party', l_r.request_status = 'DRAFT' and l_r.party_id is null);
    ok('step 1 keeps the business relationship', l_r.business_relationship = 'VENDOR');
    ok('step 1 gives the questionnaire of the party type',
       l_r.questionnaire_code = xxcmp_request_pkg.questionnaire_code('ORGANIZATION'));
    xxcmp_request_pkg.save_intake(l_req, 'PERSON', xxcmp_request_pkg.default_department, 'VENDOR');
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('another party type before step 2 changes the questionnaire',
       l_r.party_type = 'PERSON' and l_r.questionnaire_code = xxcmp_request_pkg.questionnaire_code('PERSON'));
    xxcmp_request_pkg.save_intake(l_req, 'ORGANIZATION', xxcmp_request_pkg.default_department, 'VENDOR');

    -- step 2
    l_txt := xxcmp_request_pkg.request_error(l_req, 'NEW', null, 'ORGANIZATION', 'R103 ' || l_tag, 'AE', 'CR-' || l_tag,
                                             'PRIVATE_COMPANY', null, null, null, null,
                                             p_registration_type => 'COMMERCIAL_REGISTRATION',
                                             p_business_relationship => xxcmp_request_pkg.business_relationship(l_req));
    ok('step 2 asks the justification when KYC is required (or nothing when it is not): ' || l_txt,
       l_txt is null or l_txt = 'Enter the business justification.');
    xxcmp_request_pkg.save_counterparty(l_req, 'NEW', null, 'ORGANIZATION', 'R103 ' || l_tag, 'AE', 'CR-' || l_tag,
                                        'PRIVATE_COMPANY', 'COMMERCIAL_REGISTRATION', null, null, null, null, null, null,
                                        'Why', p_draft => 'Y');
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('step 2 creates the Pending party', l_r.party_id is not null
       and xxcmp_party_pkg.party_status(l_r.party_id) = 'PENDING' and l_r.party_name = 'R103 ' || l_tag);
    ok('step 2 saves the justification', l_r.justification = 'Why');
    ok('step 2 keeps the business relationship of step 1', l_r.business_relationship = 'VENDOR');
    xxcmp_request_pkg.save_intake(l_req, 'PERSON', xxcmp_request_pkg.default_department, 'CUSTOMER');
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('the party type no longer changes once the party is entered', l_r.party_type = 'ORGANIZATION');
    ok('step 1 still changes the business relationship', l_r.business_relationship = 'CUSTOMER');
    rollback;
    apex_session.delete_session;
exception
    when others then
        rollback;
        dbms_output.put_line('FAIL ' || sqlerrm);
end;
/
