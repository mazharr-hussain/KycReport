-- Release 75 (KYC, run as XXCUS): the case is assigned at request level. The officer rule (XXCMP_CASE_PKG.IS_CASE_OFFICER),
-- the Approve popup condition (XXCMP_REQUEST_PKG.OPENS_CASE_ON_APPROVAL), an invalid officer refused, and the approval that
-- opens the case giving it to the officer chosen (not the approver); then Assign from the request screen (same case
-- package procedure). Needs security_test.sql and workflow_test.sql first (REQ1, OFFICER1, MGR1, HOC1).
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_req   number;
    l_case  number;
    l_task  number;
    l_txt   varchar2(4000);
    l_c     xxcmp_cases%rowtype;

    procedure session_as(p_user varchar2) is
    begin
        if apex_application.g_instance is not null then
            apex_session.delete_session;
        end if;
        apex_session.create_session(l_app, 1, p_user);
    end;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    procedure answer(p_req number, p_q varchar2, p_label varchar2) is
    begin
        update xxcmp_request_answers a
           set answer_option_id = (select o.answer_option_id from xxcmp_answer_options o
                                    where o.question_id = a.question_id and o.answer_label = p_label)
         where a.request_id = p_req and a.respondent_type = 'REQUESTER'
           and a.question_id = (select q.question_id from xxcmp_questions q
                                 where q.questionnaire_code = 'CORPORATE' and q.question_text like '%' || p_q || '%');
    end;
    function open_task(p_def varchar2, p_pk varchar2) return number is
        l number;
    begin
        select max(task_id) into l from apex_tasks
         where task_def_static_id = p_def and detail_pk = p_pk and state_code in ('UNASSIGNED', 'ASSIGNED');
        return l;
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
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';

    ok('case officers: OFFICER1 / MGR1 yes, REQ1 no',
       xxcmp_case_pkg.is_case_officer('OFFICER1') = 'Y' and xxcmp_case_pkg.is_case_officer('mgr1') = 'Y'
       and xxcmp_case_pkg.is_case_officer('REQ1') = 'N');

    -- a request that needs KYC, waiting for its (single) Compliance approval step
    session_as('REQ1');
    xxcmp_request_pkg.save_request(l_req, 'NEW', null, 'ORGANIZATION', dbms_random.string('U', 16), 'AE',
               'R75' || to_char(systimestamp, 'HH24MISSFF3'), 'LLC', null,
               'contact@example.com', '+971 4 000 0000', null, null, 'PROCUREMENT', 'Release 75 assignment test',
               p_registration_type => 'COMMERCIAL_REGISTRATION', p_business_relationship => 'VENDOR');
    answer(l_req, 'regulated stock exchange', 'No');
    answer(l_req, 'country of incorporation', 'Medium-risk jurisdiction');
    answer(l_req, 'transaction volume', 'Above 10 million');
    answer(l_req, 'politically exposed', 'No');
    answer(l_req, 'cash-intensive', 'Yes');
    xxcmp_request_pkg.submit(l_req);
    commit;
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''DOC_CHECKLIST_REVIEW'' and detail_pk = ''' || l_req || '''');
    l_task := open_task('DOC_CHECKLIST_REVIEW', to_char(l_req));
    ok('the approval of this step opens the case (Approve popup shown): '
       || xxcmp_request_pkg.opens_case_on_approval(l_req), xxcmp_request_pkg.opens_case_on_approval(l_req) = 'Y');

    session_as('OFFICER1');
    begin
        xxcmp_request_pkg.set_case_assignee(l_req, 'REQ1');
        ok('a requester cannot be chosen as the case officer', false);
    exception when others then
        ok('a requester cannot be chosen as the case officer: ' || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+'),
           sqlcode = -20619);
    end;
    -- the approver (OFFICER1) gives the case to MGR1 in the popup, then approves
    xxcmp_request_pkg.set_case_assignee(l_req, 'mgr1');
    apex_human_task.approve_task(l_task, p_autoclaim => true);
    commit;
    wait_for('select count(*) from xxcmp_cases where request_id = ' || l_req);
    select max(case_id) into l_case from xxcmp_cases where request_id = l_req;
    select * into l_c from xxcmp_cases where case_id = l_case;
    ok('the case opened on approval goes to the officer chosen (MGR1), not the approver: ' || l_c.assigned_to,
       l_c.assigned_to = 'MGR1');
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''CASE_INVESTIGATION'' and detail_pk = ''' || l_case || '''');
    l_task := open_task('CASE_INVESTIGATION', to_char(l_case));
    select listagg(participant, ',') within group (order by participant) into l_txt
      from apex_task_participants
     where task_id = l_task and participant_type = 'POTENTIAL_OWNER';
    ok('the investigation task is MGR1''s: ' || l_txt, instr(l_txt, 'MGR1') > 0);

    -- Assign Case on the approved request (205): the same case procedure, allowed to a Cases manager (a business
    -- administrator of the investigation task, so the task moves with the case)
    session_as('MGR1');
    ok('MGR1 may assign the case from the request: ' || xxcmp_case_pkg.can_assign(l_case), xxcmp_case_pkg.can_assign(l_case) = 'Y');
    xxcmp_case_pkg.assign(l_case, 'OFFICER1', 'Release 75 test');
    select * into l_c from xxcmp_cases where case_id = l_case;
    ok('reassigned to OFFICER1 with a note: ' || l_c.assigned_to, l_c.assigned_to = 'OFFICER1');
    select listagg(participant, ',') within group (order by participant) into l_txt
      from apex_task_participants
     where task_id = l_task and participant_type = 'POTENTIAL_OWNER';
    ok('the investigation task follows the case (OFFICER1 only): ' || l_txt, l_txt = 'OFFICER1');
    begin
        xxcmp_case_pkg.assign(l_case, 'REQ1');
        ok('a non-officer cannot be given the case', false);
    exception when others then
        ok('a non-officer cannot be given the case', sqlcode = -20619);
    end;
    rollback;
    apex_session.delete_session;
end;
/
exit
