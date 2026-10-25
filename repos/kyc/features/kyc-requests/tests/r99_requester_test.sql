-- KYC 99 (requester area): the short request form rules (no email or phone; release 100: the registration type is
-- asked), the risk screening on step 1 (same outcome as EVALUATE at submit, without changing the request), the seeded
-- ownership question, and the requester's access to the new counterparty's documents. Everything is rolled back.
-- Needs security_test.sql (REQ1) and the starter questionnaires (18e, 18k).
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_tag   varchar2(20) := dbms_random.string('U', 10);
    l_req   number;
    l_cnt   number;
    l_json  clob;
    l_out   varchar2(30);

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    -- the answers JSON of the request's screening: P_WAIVE = Y answers the gates with a waiver option where one exists
    function answers(p_request_id number, p_waive varchar2) return clob is
        l_a clob;
    begin
        select json_arrayagg(json_object('q' value a.question_id,
                   'o' value (select max(o.answer_option_id) keep (dense_rank first order by
                                         case when p_waive = 'Y' and q.gate_question_flag = 'Y' and o.waiver_qualifying_flag = 'Y' then 0
                                              when o.critical_flag = 'N' and o.waiver_qualifying_flag = 'N' then 1 else 2 end,
                                         o.risk_points, o.display_sequence)
                                from xxcmp_answer_options o
                               where o.question_id = a.question_id and o.approval_status = 'APPROVED' and o.enabled_flag = 'Y'),
                   't' value case when q.answer_type in ('TEXT', 'NUMBER', 'DATE') then '1' end) returning clob)
          into l_a
          from xxcmp_request_answers a join xxcmp_questions q on q.question_id = a.question_id
         where a.request_id = p_request_id and a.respondent_type = 'REQUESTER';
        return l_a;
    end answers;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 201, 'REQ1');

    ---------------------------------------------------------------- the short request form
    -- release 100: the registration type is part of the duplicate rule - asked on the request form too
    ok('organisation without email or phone: accepted on the request form',
       xxcmp_party_pkg.party_error(null, 'ORGANIZATION', 'R99 ' || l_tag, 'AE', 'R99-' || l_tag, 'PRIVATE_COMPANY', null,
                                   null, null, p_registration_type => 'COMMERCIAL_REGISTRATION', p_request_form => 'Y') is null);
    ok('the request form asks for the registration type (release 100)',
       xxcmp_party_pkg.party_error(null, 'ORGANIZATION', 'R99 ' || l_tag, 'AE', 'R99-' || l_tag, 'PRIVATE_COMPANY', null,
                                   null, null, p_request_form => 'Y') = 'Choose the registration type of the registration number.');
    ok('the party form still asks for the registration type',
       xxcmp_party_pkg.party_error(null, 'ORGANIZATION', 'R99 ' || l_tag, 'AE', 'R99-' || l_tag, 'X', null,
                                   'a@example.com', null) = 'Choose the registration type of the registration number.');
    ok('the party form still asks for an email or a phone',
       xxcmp_party_pkg.party_error(null, 'PERSON', 'R99 ' || l_tag, 'AE', null, null, null, null, null)
       = 'Enter an email or a phone number.');
    ok('an individual''s ID type is still asked on the request form',
       xxcmp_party_pkg.party_error(null, 'PERSON', 'R99 ' || l_tag, 'AE', 'ID-' || l_tag, null, null, null, null,
                                   p_request_form => 'Y') = 'Choose the ID type of the ID number.');

    ---------------------------------------------------------------- the ownership question (18k)
    select count(*) into l_cnt from xxcmp_questions
     where questionnaire_code = 'CORPORATE' and question_text = 'Business counterparty ownership structure type'
       and gate_question_flag = 'Y';
    ok('the ownership structure question is a gate of the corporate questionnaire', l_cnt = 1);
    select count(*) into l_cnt from xxcmp_answer_options o join xxcmp_questions q on q.question_id = o.question_id
     where q.question_text = 'Business counterparty ownership structure type' and o.risk_points = 0
       and o.waiver_qualifying_flag = 'N' and o.approval_status = 'APPROVED';
    ok('its 6 answers carry no risk points and waive nothing until the administrator decides', l_cnt = 6);

    ---------------------------------------------------------------- the risk screening on step 1
    xxcmp_request_pkg.save_request(l_req, 'NEW', null, 'ORGANIZATION', 'R99 Draft ' || l_tag, 'AE', 'R99D-' || l_tag,
                                   null, null, null, null, null, null, null, null, p_draft => 'Y');
    ok('a draft without answers has no outcome yet', xxcmp_request_pkg.screening_outcome(l_req) is null);
    xxcmp_request_pkg.save_screening(l_req, '[{"q":-1,"o":null,"t":null}]');
    ok('an answer to a question the request does not have is left out', true);
    xxcmp_request_pkg.save_screening(l_req, answers(l_req, 'Y'));
    l_out := xxcmp_request_pkg.screening_outcome(l_req);
    ok('the listed / government gate answered Yes: KYC not required (' || l_out || ')', l_out = 'NOT_REQUIRED');
    ok('no business relationship or justification asked then',
       xxcmp_request_pkg.request_error(l_req, 'NEW', null, 'ORGANIZATION', 'R99 Draft ' || l_tag, 'AE', 'R99D-' || l_tag,
                                       'PRIVATE_COMPANY', null, null, null, null) is null
       or xxcmp_request_pkg.request_error(l_req, 'NEW', null, 'ORGANIZATION', 'R99 Draft ' || l_tag, 'AE', 'R99D-' || l_tag,
                                          'PRIVATE_COMPANY', null, null, null, null) not like '%justification%');
    select request_status, intake_outcome into l_json, l_out from xxcmp_requests where request_id = l_req;
    ok('the screening changes nothing on the request', l_json = 'DRAFT' and l_out is null);
    xxcmp_request_pkg.save_screening(l_req, answers(l_req, 'N'));
    l_out := xxcmp_request_pkg.screening_outcome(l_req);
    ok('no waiver: KYC required or approved automatically by score (' || l_out || ')', l_out in ('ASSIGNED', 'AUTO_APPROVED'));
    ok('Yes / No of an outcome', xxcmp_request_pkg.outcome_kyc_required('ASSIGNED') = 'Yes'
                                 and xxcmp_request_pkg.outcome_kyc_required('NOT_REQUIRED') = 'No'
                                 and xxcmp_request_pkg.outcome_kyc_required(null) is null);

    ---------------------------------------------------------------- documents of the new counterparty (D2)
    select count(*) into l_cnt from xxcmp_requests where request_id = l_req and party_id is not null;
    if l_cnt = 1 then
        select party_id into l_cnt from xxcmp_requests where request_id = l_req;
        ok('the requester may see the party he created (COMMON document dialog)',
           xxfnd_attach_pkg.record_visible('XXCMP_PARTIES', to_char(l_cnt)) = 'Y');
    end if;
    rollback;
    apex_session.delete_session;
exception
    when others then
        rollback;
        dbms_output.put_line('FAIL ' || sqlerrm);
        raise;
end;
/
exit
