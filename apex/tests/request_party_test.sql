-- Request module: existing/new counterparty, possible-match detection, exact-match block, contact details,
-- requesting department from the employee profile, mandatory documents at submit, and the Compliance merge /
-- confirm-new decision inside the document checklist review (workflow 1.2).
-- Needs security_test.sql (REQ1, OFFICER1). Creates its own parties with a run tag.
set serveroutput on size unlimited feedback off
declare
    l_app    number;
    l_tag    varchar2(20) := to_char(systimestamp, 'HH24MISSFF3');
    l_rand   varchar2(20) := dbms_random.string('U', 16);   -- resembles no party of earlier runs
    l_org    number;
    l_person number;
    l_req    number;
    l_req2   number;
    l_task   number;
    l_cnt    number;
    l_txt    varchar2(4000);
    l_json   clob;
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
    -- low-risk answers: the score alone would auto-approve the request
    procedure answer_low(p_req number) is
    begin
        for a in (select a.question_id, q.question_text from xxcmp_request_answers a join xxcmp_questions q on q.question_id = a.question_id
                   where a.request_id = p_req and a.respondent_type = 'REQUESTER') loop
            update xxcmp_request_answers x
               set answer_option_id = (select min(o.answer_option_id) keep (dense_rank first order by o.risk_points, o.display_sequence)
                                         from xxcmp_answer_options o
                                        where o.question_id = a.question_id and o.approval_status = 'APPROVED'
                                          and o.waiver_qualifying_flag = 'N')
             where x.request_id = p_req and x.question_id = a.question_id;
        end loop;
    end;
    function new_org(p_name varchar2, p_reg varchar2, p_inc date, p_ack varchar2 default 'Y') return number is
        l number;
    begin
        xxcmp_request_pkg.save_counterparty(l, 'NEW', null, 'ORGANIZATION', p_name, p_reg, 'LLC', p_inc, null, null, 'AE',
                                            null, null, 'FINANCE', 'Test', p_ack,
                                            p_contact_name => 'Test Contact', p_contact_email => 'contact@example.com',
                                            p_contact_phone => '+971 4 000 0000');
        return l;
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    -- existing parties (as the schema: no APEX user, full access)
    insert into xxcmp_parties (party_type, party_name, registration_number, jurisdiction, entity_type)
    values ('ORGANIZATION', 'Alpha Trading ' || l_tag || ' LLC', 'CR-' || l_tag, 'AE', 'LLC') returning party_id into l_org;
    insert into xxcmp_parties (party_type, party_name, date_of_birth, nationality, jurisdiction, id_type, id_number)
    values ('PERSON', 'John Smith ' || l_tag, date '1980-01-01', 'AE', 'AE', 'PASSPORT', 'P' || l_tag) returning party_id into l_person;
    commit;

    ---------------------------------------------------------------- matching
    session_as('REQ1');
    select count(*) into l_cnt from xxcmp_parties where party_id = l_org;
    ok('the requester cannot read the party master', l_cnt = 0);
    l_json := xxcmp_request_pkg.party_directory_json('ORGANIZATION');
    ok('but can choose from the party list (number, name, country only)',
       instr(l_json, 'Alpha Trading ' || l_tag) > 0 and instr(l_json, 'CR-' || l_tag) = 0);
    l_json := xxcmp_request_pkg.party_candidates_json('ORGANIZATION', 'Other Name', 'cr ' || l_tag, null, null, 'AE');
    ok('same registration number (other spelling) and country -> 100%, exact: ' || dbms_lob.substr(l_json, 260, 1),
       instr(l_json, '"score":100') > 0 and instr(l_json, '"exact":"Y"') > 0 and instr(l_json, '"reg_match":100') > 0
       and instr(l_json, '"registration_number":"CR-' || l_tag || '"') > 0);
    l_json := xxcmp_request_pkg.party_candidates_json('ORGANIZATION', 'Other Name', 'cr ' || l_tag, null, null, 'QA');
    ok('same registration number, other country -> 90%, not exact: ' || regexp_substr(l_json, '"score":[0-9]+'),
       instr(l_json, '"score":90') > 0 and instr(l_json, '"exact":"N"') > 0);
    l_json := xxcmp_request_pkg.party_candidates_json('ORGANIZATION', 'Alpha Trading ' || l_tag || ' LLC', 'CR-' || l_tag || 'X', null, null, 'AE');
    ok('registration match % for a close number: ' || regexp_substr(l_json, '"reg_match":[0-9]+'),
       regexp_like(l_json, '"reg_match":(8|9)[0-9]'));
    l_json := xxcmp_request_pkg.party_candidates_json('ORGANIZATION', 'Alpha Tradin ' || l_tag || ' LLC', null, null, null, 'AE');
    ok('similar name and same country: ' || regexp_substr(l_json, '"reasons":"[^"]*"'), instr(l_json, 'Alpha Trading ' || l_tag) > 0);
    l_json := xxcmp_request_pkg.party_candidates_json('PERSON', 'Jon Smyth', null, 'p-' || l_tag, date '1980-01-01', null);
    ok('individual: same identity document and date of birth: ' || regexp_substr(l_json, '"reasons":"[^"]*"'),
       instr(l_json, 'Same identity document number') > 0 and instr(l_json, 'Same date of birth') > 0);
    ok('an unrelated name finds nothing',
       xxcmp_request_pkg.party_candidate_count('ORGANIZATION', l_rand, 'ZZ-' || l_tag, null, null, null) = 0);

    ---------------------------------------------------------------- requester
    l_req := null;
    xxcmp_request_pkg.save_counterparty(l_req, 'EXISTING', l_org, null, null, null, null, null, null, null, null, null, null,
                                        'FINANCE', 'Existing supplier');
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('existing party chosen: details copied, ' || l_r.match_status, l_r.party_id = l_org and l_r.party_name like 'Alpha Trading%'
       and l_r.registration_number = 'CR-' || l_tag and l_r.match_status = 'SELECTED');
    l_req := null;
    begin
        xxcmp_request_pkg.save_counterparty(l_req, 'NEW', null, 'ORGANIZATION', 'Draft Only ' || l_tag, null, null, null, null, null,
                                            null, null, null, null, null, 'N', 'Y');
        ok('a draft needs only the type and name', l_req is not null);
    exception when others then
        ok('a draft needs only the type and name: ' || sqlerrm, false);
    end;
    -- same registration number and country: never a new party, even confirmed
    begin
        l_req := new_org('Alpha Trading Copy ' || l_tag, 'cr-' || l_tag, date '2015-03-01', 'Y');
        ok('same registration number and country is refused even when confirmed', false);
    exception when others then
        ok('same registration number and country is refused even when confirmed: '
           || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+'), sqlcode = -20611 and instr(sqlerrm, 'use this party') > 0);
    end;
    -- contact details are required, the other details are optional
    l_req := null;
    begin
        xxcmp_request_pkg.save_counterparty(l_req, 'NEW', null, 'ORGANIZATION', 'No Contact ' || l_tag, null, null, null, null,
                                            null, null, null, null, 'FINANCE', 'Test');
        ok('a new counterparty needs contact details', false);
    exception when others then
        ok('a new counterparty needs contact details: ' || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+'),
           instr(sqlerrm, 'contact') > 0);
    end;
    l_req := null;
    xxcmp_request_pkg.save_counterparty(l_req, 'NEW', null, 'ORGANIZATION', 'Only Contact ' || l_rand, null, null, null, null,
                                        null, null, null, null, 'FINANCE', 'Test',
                                        p_contact_name => 'A Person', p_contact_email => 'a@b.co', p_contact_phone => '123');
    ok('name and contact details are enough (registration, type, country optional)', l_req is not null);
    -- requesting department: the employee profile's for a requester
    update xxfnd_employees set department_name = 'Procurement' where user_name = 'REQ1';
    ok('the department defaults from the employee profile: ' || xxcmp_request_pkg.default_department,
       xxcmp_request_pkg.default_department = 'PROCUREMENT' and xxcmp_request_pkg.can_choose_department = 'N');
    l_req2 := null;
    xxcmp_request_pkg.save_counterparty(l_req2, 'EXISTING', l_org, null, null, null, null, null, null, null, null, null, null,
                                        'SALES', 'Other department asked');
    select requesting_department into l_txt from xxcmp_requests where request_id = l_req2;
    ok('a requester cannot raise it for another department: ' || l_txt, l_txt = 'PROCUREMENT');
    -- mandatory documents of the country / entity type must be attached before submitting
    select min(r.jurisdiction) into l_txt from xxcmp_attachment_rules r
     where r.entity_name = 'XXCMP_PARTIES' and r.mandatory_flag = 'Y' and r.enabled_flag = 'Y'
       and r.approval_status = 'APPROVED' and r.entity_type is null and r.jurisdiction is not null;
    if l_txt is not null then
        l_req2 := null;
        xxcmp_request_pkg.save_counterparty(l_req2, 'NEW', null, 'ORGANIZATION', 'Docs ' || l_rand, 'DOC-' || l_tag, 'LLC', null,
                                            null, null, l_txt, null, null, 'FINANCE', 'Test',
                                            p_contact_name => 'A Person', p_contact_email => 'a@b.co', p_contact_phone => '123');
        answer_low(l_req2);
        ok('mandatory documents missing: ' || xxcmp_request_pkg.submit_error(l_req2),
           instr(xxcmp_request_pkg.submit_error(l_req2), 'Attach the mandatory documents') > 0);
    else
        ok('mandatory documents check (no country rule configured: skipped)', true);
    end if;
    l_req := new_org('Alpha Trading ' || l_tag || ' L.L.C.', 'NEWREG' || l_tag, date '2015-03-01');
    answer_low(l_req);
    xxcmp_request_pkg.submit(l_req);
    commit;
    wait_for('select count(*) from xxcmp_requests where request_id = ' || l_req || ' and intake_outcome is not null');
    select * into l_r from xxcmp_requests where request_id = l_req;
    ok('possible duplicate -> ' || l_r.match_status || ', no party yet, to Compliance even with score ' || l_r.intake_score
       || ' (' || l_r.intake_outcome || ')',
       l_r.match_status = 'PENDING' and l_r.party_id is null and l_r.intake_outcome = 'ASSIGNED');
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''DOC_CHECKLIST_REVIEW'' and detail_pk = ''' || l_req || '''');
    select max(task_id) into l_task from apex_tasks where task_def_static_id = 'DOC_CHECKLIST_REVIEW' and detail_pk = to_char(l_req);
    select listagg(participant, ',') within group (order by participant) into l_txt
      from apex_task_participants where task_id = l_task and participant_type = 'POTENTIAL_OWNER';
    ok('the workflow goes straight to Compliance''s checklist review, which includes the match decision (' || l_txt || ')',
       l_task is not null and instr(l_txt, 'OFFICER1') > 0 and instr(l_txt, 'REQ1') = 0);
    select count(*) into l_cnt from apex_tasks where task_def_static_id = 'COUNTERPARTY_MATCH' and detail_pk = to_char(l_req);
    ok('no separate Counterparty Match task', l_cnt = 0);
    begin
        xxcmp_request_pkg.resolve_match(l_req, l_org);
        ok('the requester cannot merge', false);
    exception when others then
        ok('the requester cannot merge: ' || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+'), true);
    end;

    ---------------------------------------------------------------- Compliance
    session_as('OFFICER1');
    xxcmp_request_pkg.resolve_match(l_req, l_org, 'Same registration, spelling of the name differs.');
    commit;
    select * into l_r from xxcmp_requests where request_id = l_req;
    select to_char(incorporation_date, 'YYYY-MM-DD') into l_txt from xxcmp_parties where party_id = l_org;
    ok('merged into the existing party by ' || l_r.match_resolved_by || '; its empty incorporation date completed: ' || l_txt,
       l_r.match_status = 'MERGED' and l_r.party_id = l_org and l_txt = '2015-03-01');
    begin
        xxcmp_request_pkg.resolve_match(l_req, null);
        ok('a decided counterparty cannot be decided again', false);
    exception when others then
        ok('a decided counterparty cannot be decided again', true);
    end;
    select count(*) into l_cnt from xxcmp_party_contacts where party_id = l_org and contact_type = 'EMAIL';
    ok('merge keeps the existing party''s contacts (none added)', l_cnt = 0);
    apex_human_task.approve_task(l_task, p_autoclaim => true);
    commit;
    wait_for('select count(*) from xxcmp_cases where request_id = ' || l_req);
    select count(*) into l_cnt from xxcmp_cases where request_id = l_req and party_id = l_org;
    ok('approved now: the case is opened for the existing party', l_cnt = 1);

    -- confirm as new
    session_as('REQ1');
    l_req2 := new_org('Alpha Tradin ' || l_tag || ' LLC', 'NEW-' || l_tag, null);
    answer_low(l_req2);
    xxcmp_request_pkg.submit(l_req2);
    commit;
    wait_for('select count(*) from xxcmp_requests where request_id = ' || l_req2 || ' and match_status is not null');
    session_as('OFFICER1');
    xxcmp_request_pkg.resolve_match(l_req2, null, 'Different registration: another company.');
    commit;
    select * into l_r from xxcmp_requests where request_id = l_req2;
    select count(*) into l_cnt from xxcmp_parties where party_id = l_r.party_id and registration_number = 'NEW-' || l_tag;
    ok('confirmed as new: ' || l_r.match_status || ', new party created', l_r.match_status = 'CONFIRMED_NEW' and l_cnt = 1);
    select count(*) into l_cnt from xxcmp_parties p
     where p.party_id = l_r.party_id and p.email = 'contact@example.com' and p.phone is not null
       and exists (select 1 from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'PERSON'
                      and c.contact_name = 'Test Contact' and c.email = 'contact@example.com' and c.primary_flag = 'Y');
    ok('the new party gets the email and phone, and the contact person', l_cnt = 1);

    -- nothing similar: a new party at once, and the normal intake rules apply
    session_as('REQ1');
    l_req2 := new_org(l_rand, 'ZZ-' || l_tag, null);
    answer_low(l_req2);
    xxcmp_request_pkg.submit(l_req2);
    commit;
    wait_for('select count(*) from xxcmp_requests where request_id = ' || l_req2 || ' and intake_outcome is not null');
    select * into l_r from xxcmp_requests where request_id = l_req2;
    ok('no similar party: ' || l_r.match_status || ', party linked, intake ' || l_r.intake_outcome,
       l_r.match_status = 'NEW' and l_r.party_id is not null and l_r.intake_outcome <> 'ASSIGNED');
    apex_session.delete_session;
    update xxfnd_employees set department_name = null where user_name = 'REQ1';
    commit;
end;
/
exit
