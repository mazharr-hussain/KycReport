-- Chunk 5: KYC_REQUEST and KYC_CASE workflows end to end, in APEX sessions of the real users.
-- Needs security_test.sql and workflow_test.sql first (REQ1, OFFICER1, MGR1, HOC1).
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_req   number;
    l_case  number;
    l_task  number;
    l_cnt   number;
    l_txt   varchar2(4000);
    l_row   xxcmp_requests%rowtype;
    l_c     xxcmp_cases%rowtype;
    l_err   varchar2(4000);

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
    -- answer a question (by text fragment) with an option (by label)
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
         where task_def_static_id = p_def and detail_pk = p_pk and state_code in ('UNASSIGNED','ASSIGNED');
        return l;
    end;
    function owners(p_task number) return varchar2 is
        l varchar2(4000);
    begin
        select listagg(participant, ',') within group (order by participant) into l
          from apex_task_participants where task_id = p_task and participant_type = 'POTENTIAL_OWNER';
        return l;
    end;
    -- APEX runs workflow activities in a background job after commit: wait until p_sql counts > 0.
    procedure wait_for(p_sql varchar2) is
        l number;
    begin
        for i in 1 .. 90 loop
            execute immediate p_sql into l;
            exit when l > 0;
            dbms_session.sleep(1);
        end loop;
    end;
    function new_request(p_name varchar2) return number is
    begin
        return xxcmp_request_pkg.create_request(p_party_type => 'ORGANIZATION', p_party_name => p_name,
                   p_registration_number => upper(replace(p_name, ' ')) || to_char(sysdate, 'HH24MISS'),
                   p_jurisdiction => 'AE', p_entity_type => 'LLC', p_requesting_department => 'PROCUREMENT',
                   p_justification => 'New supplier');
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';

    -------------------------------------------------------------- waiver path
    session_as('REQ1');
    l_req := new_request('Listed Holdings');
    answer(l_req, 'regulated stock exchange', 'Yes');
    answer(l_req, 'country of incorporation', 'Low-risk jurisdiction');
    answer(l_req, 'transaction volume', 'Below 1 million');
    answer(l_req, 'politically exposed', 'No');
    answer(l_req, 'cash-intensive', 'No');
    xxcmp_request_pkg.submit(l_req);
    commit;
    ok('right after submitting, the requester sees: ' || xxcmp_request_pkg.stage(l_req), xxcmp_request_pkg.stage(l_req) = 'Processing');
    wait_for('select count(*) from xxcmp_requests where request_id = ' || l_req || ' and request_status <> ''SUBMITTED''');
    select * into l_row from xxcmp_requests where request_id = l_req;
    ok('listed company (gate answer) -> ' || l_row.intake_outcome || ' / ' || l_row.request_status || ' / stage ' || xxcmp_request_pkg.stage(l_req),
       l_row.intake_outcome = 'NOT_REQUIRED' and l_row.request_status = 'COMPLETED');

    -------------------------------------------------------- auto-approve path
    l_req := new_request('Small Supplier');
    answer(l_req, 'regulated stock exchange', 'No');
    answer(l_req, 'country of incorporation', 'Low-risk jurisdiction');
    answer(l_req, 'transaction volume', '1 to 10 million');
    answer(l_req, 'politically exposed', 'No');
    answer(l_req, 'cash-intensive', 'No');
    xxcmp_request_pkg.submit(l_req);
    commit;
    wait_for('select count(*) from xxcmp_requests where request_id = ' || l_req || ' and request_status <> ''SUBMITTED''');
    select * into l_row from xxcmp_requests where request_id = l_req;
    ok('score ' || l_row.intake_score || ' within the low threshold -> ' || l_row.intake_outcome || ' / ' || l_row.request_status,
       l_row.intake_outcome = 'AUTO_APPROVED' and l_row.request_status = 'COMPLETED');

    ---------------------------------------------------- incomplete submission
    l_req := new_request('Incomplete Co');
    begin
        xxcmp_request_pkg.submit(l_req);
        ok('unanswered required questions block submission', false);
    exception when others then
        ok('unanswered required questions block submission: ' || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+'), true);
    end;
    rollback;

    ------------------------------------------------------- full KYC path
    l_req := new_request('Global Trading');
    answer(l_req, 'regulated stock exchange', 'No');
    answer(l_req, 'country of incorporation', 'Medium-risk jurisdiction');
    answer(l_req, 'transaction volume', 'Above 10 million');
    answer(l_req, 'politically exposed', 'No');
    answer(l_req, 'cash-intensive', 'Yes');
    xxcmp_request_pkg.submit(l_req);
    commit;
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''DOC_CHECKLIST_REVIEW'' and detail_pk = ''' || l_req || '''');
    select * into l_row from xxcmp_requests where request_id = l_req;
    ok('score ' || l_row.intake_score || ' above threshold -> ' || l_row.intake_outcome || ' / ' || l_row.request_status
       || ' / party linked: ' || nvl(to_char(l_row.party_id), 'no'),
       l_row.intake_outcome = 'ASSIGNED' and l_row.request_status = 'IN_PROGRESS' and l_row.party_id is not null);
    l_task := open_task('DOC_CHECKLIST_REVIEW', to_char(l_req));
    ok('document checklist task for Compliance: ' || owners(l_task), l_task is not null and instr(owners(l_task), 'OFFICER1') > 0);
    ok('the requester (initiator) may not approve it',
       not apex_human_task.is_allowed(l_task, apex_human_task.c_task_op_claim));
    select count(*) into l_cnt from xxcmp_requests where request_id = l_req;
    ok('the requester sees own request (data security)', l_cnt = 1);
    select count(*) into l_cnt from xxcmp_parties where party_id = l_row.party_id;
    ok('but not the party master (data security)', l_cnt = 0);

    session_as('OFFICER1');
    apex_human_task.approve_task(l_task, p_autoclaim => true);
    commit;
    wait_for('select count(*) from apex_tasks t join xxcmp_cases c on to_char(c.case_id) = t.detail_pk where t.task_def_static_id = ''CASE_INVESTIGATION'' and c.request_id = ' || l_req);
    select max(case_id) into l_case from xxcmp_cases where request_id = l_req;
    ok('checklist approved -> case opened (' || l_case || ')', l_case is not null);
    l_task := open_task('CASE_INVESTIGATION', to_char(l_case));
    ok('investigation task: ' || owners(l_task), l_task is not null);

    l_err := xxcmp_case_pkg.submit_error(l_case);
    ok('cannot submit without risk tier: ' || l_err, l_err is not null);
    update xxcmp_cases set risk_tier = 'HIGH', assigned_to = 'OFFICER1' where case_id = l_case;
    insert into xxcmp_screenings (case_id, party_id, screening_type, match_status, pep_flag)
    values (l_case, l_row.party_id, 'PEP', 'POTENTIAL_MATCH', 'Y');
    xxcmp_case_pkg.apply_screening(l_case);
    select * into l_c from xxcmp_cases where case_id = l_case;
    ok('PEP flag forces Enhanced KYC: EKYC=' || l_c.enhanced_kyc_flag || ' PEP=' || l_c.pep_flag, l_c.enhanced_kyc_flag = 'Y');
    l_err := xxcmp_case_pkg.submit_error(l_case);
    ok('Enhanced KYC needs source of funds/wealth: ' || l_err, l_err like 'Enhanced KYC%');
    update xxcmp_request_answers set answer_text = 'Trading profits'
     where case_id = l_case and respondent_type = 'OFFICER';
    xxcmp_case_pkg.submit_for_approval(l_case);
    commit;
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''CASE_APPROVAL'' and detail_pk = ''' || l_case || '''');
    select * into l_c from xxcmp_cases where case_id = l_case;
    ok('submitted: status ' || l_c.case_status || ', level ' || l_c.current_level || ' of ' || xxcmp_case_pkg.required_levels(l_case),
       l_c.case_status = 'PENDING_APPROVAL' and xxcmp_case_pkg.required_levels(l_case) = 2);
    l_task := open_task('CASE_APPROVAL', to_char(l_case));
    ok('level 1 approvers (managers, not the investigator): ' || owners(l_task),
       l_task is not null and instr(owners(l_task), 'MGR1') > 0 and instr(nvl(owners(l_task), '-'), 'OFFICER1') = 0);

    session_as('MGR1');
    l_err := xxcmp_case_pkg.approval_error(l_case);
    ok('SAR determination required before approval: ' || l_err, l_err like '%Suspicious Activity%');
    update xxcmp_cases set sar_required_flag = 'N', conditions = 'Annual review' where case_id = l_case;
    apex_human_task.add_task_comment(l_task, 'Level 1 approved.');
    apex_human_task.approve_task(l_task, p_autoclaim => true);
    commit;
    wait_for('select count(*) from apex_tasks where task_def_static_id = ''CASE_APPROVAL'' and detail_pk = ''' || l_case || ''' and state_code in (''UNASSIGNED'',''ASSIGNED'')');
    l_task := open_task('CASE_APPROVAL', to_char(l_case));
    ok('level 2 approvers (Head of Compliance): ' || owners(l_task), l_task is not null and instr(owners(l_task), 'HOC1') > 0
       and instr(owners(l_task), 'MGR1') = 0);

    session_as('HOC1');
    apex_human_task.approve_task(l_task, p_autoclaim => true);
    commit;
    wait_for('select count(*) from xxcmp_cases where case_id = ' || l_case || ' and closed_date is not null');
    select * into l_c from xxcmp_cases where case_id = l_case;
    select * into l_row from xxcmp_requests where request_id = l_req;
    ok('level 2 approved -> case ' || l_c.case_status || ', closed ' || to_char(l_c.closed_date, 'DD-Mon')
       || ', next review ' || to_char(l_c.next_review_date, 'DD-Mon-YYYY') || '; request ' || l_row.request_status,
       l_c.case_status = 'APPROVED' and l_c.closed_date is not null and l_row.request_status = 'COMPLETED'
       and l_c.next_review_date = add_months(trunc(sysdate), 12));
    select listagg(level_no || ':' || decided_by || ':' || outcome, ', ') within group (order by level_no) into l_txt
      from xxcmp_case_decisions where case_id = l_case;
    ok('decision history: ' || l_txt, l_txt = '1:MGR1:APPROVED, 2:HOC1:APPROVED');
    select count(*) into l_cnt from apex_workflows where workflow_def_static_id = 'KYC_CASE' and detail_pk = to_char(l_case) and state_code = 'COMPLETED';
    ok('case workflow completed', l_cnt = 1);
    begin
        update xxcmp_cases set risk_tier = 'LOW' where case_id = l_case;
        ok('a closed case is locked', false);
    exception when others then
        ok('a closed case is locked: ' || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+'), true);
    end;
    rollback;
    apex_session.delete_session;
end;
/
exit
