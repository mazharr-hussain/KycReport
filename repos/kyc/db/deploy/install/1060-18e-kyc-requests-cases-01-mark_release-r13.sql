--------------------------------------------------------------------------------
-- 18e KYC requests and cases - seed (release R13)
-- Starter questionnaire content, open cases' assignee, the pending configuration changes view, KYC messages.
--   Release 87: the lookups, document entities, attachment pages, data access rules, page mapping, grants, task
--   deadlines and configuration tables are registered in COMMON by 18h (COMMON's registration routines).
-- Idempotent; everything an administrator maintains is insert-only.
--------------------------------------------------------------------------------
declare
    function question(p_qnr in varchar2, p_seq in number, p_text in varchar2, p_type in varchar2,
                      p_gate in varchar2 default 'N', p_required in varchar2 default 'Y',
                      p_section in varchar2 default null) return number is
        l_id number;
    begin
        insert into xxcmp_questions (questionnaire_code, question_text, answer_type, gate_question_flag, required_flag,
                                     display_sequence, section_name)
        values (p_qnr, p_text, p_type, p_gate, p_required, p_seq, p_section)
        returning question_id into l_id;
        return l_id;
    end question;

    procedure answer(p_question in number, p_seq in number, p_label in varchar2, p_points in number,
                     p_critical in varchar2 default 'N', p_waiver in varchar2 default 'N') is
    begin
        insert into xxcmp_answer_options (question_id, answer_label, risk_points, critical_flag, waiver_qualifying_flag,
                                          display_sequence, approval_status)
        values (p_question, p_label, p_points, p_critical, p_waiver, p_seq, 'APPROVED');
    end answer;

    procedure starter_questions is
        l_q     number;
        l_count pls_integer;
    begin
        -- Starter content only for questionnaires that have no questions yet.
        select count(*) into l_count from xxcmp_questions where questionnaire_code = 'CORPORATE';
        if l_count = 0 then
            l_q := question('CORPORATE', 10, 'Is the counterparty listed on a regulated stock exchange, or a government entity?', 'YES_NO', p_gate => 'Y');
            answer(l_q, 10, 'Yes', 0, p_waiver => 'Y');
            answer(l_q, 20, 'No', 0);
            l_q := question('CORPORATE', 20, 'Risk of the country of incorporation', 'SINGLE_SELECT');
            answer(l_q, 10, 'Low-risk jurisdiction', 0);
            answer(l_q, 20, 'Medium-risk jurisdiction', 5);
            answer(l_q, 30, 'High-risk or sanctioned jurisdiction', 20, p_critical => 'Y');
            l_q := question('CORPORATE', 30, 'Expected annual transaction volume', 'SINGLE_SELECT');
            answer(l_q, 10, 'Below 1 million', 0);
            answer(l_q, 20, '1 to 10 million', 5);
            answer(l_q, 30, 'Above 10 million', 10);
            l_q := question('CORPORATE', 40, 'Is any owner, director or signatory a politically exposed person?', 'YES_NO');
            answer(l_q, 10, 'Yes', 15, p_critical => 'Y');
            answer(l_q, 20, 'No', 0);
            l_q := question('CORPORATE', 50, 'Is the business cash-intensive?', 'YES_NO');
            answer(l_q, 10, 'Yes', 10);
            answer(l_q, 20, 'No', 0);
        end if;
        select count(*) into l_count from xxcmp_questions where questionnaire_code = 'INDIVIDUAL';
        if l_count = 0 then
            l_q := question('INDIVIDUAL', 10, 'Is the individual an employee of the organisation acting in that capacity?', 'YES_NO', p_gate => 'Y');
            answer(l_q, 10, 'Yes', 0, p_waiver => 'Y');
            answer(l_q, 20, 'No', 0);
            l_q := question('INDIVIDUAL', 20, 'Risk of the country of residence', 'SINGLE_SELECT');
            answer(l_q, 10, 'Low-risk jurisdiction', 0);
            answer(l_q, 20, 'Medium-risk jurisdiction', 5);
            answer(l_q, 30, 'High-risk or sanctioned jurisdiction', 20, p_critical => 'Y');
            l_q := question('INDIVIDUAL', 30, 'Is the individual a politically exposed person?', 'YES_NO');
            answer(l_q, 10, 'Yes', 15, p_critical => 'Y');
            answer(l_q, 20, 'No', 0);
        end if;
        select count(*) into l_count from xxcmp_questions where questionnaire_code = 'OFFICER_INVESTIGATION';
        if l_count = 0 then
            l_q := question('OFFICER_INVESTIGATION', 10, 'Summary of findings', 'TEXT', p_required => 'N', p_section => 'Findings');
            l_q := question('OFFICER_INVESTIGATION', 20, 'Source of funds', 'TEXT', p_required => 'N', p_section => 'Enhanced Due Diligence');
            l_q := question('OFFICER_INVESTIGATION', 30, 'Source of wealth', 'TEXT', p_required => 'N', p_section => 'Enhanced Due Diligence');
        end if;
    end starter_questions;
begin
    xxfnd_util_pkg.set_install_mode(true);
    starter_questions;
    -- Sections for the starter questions (only where an administrator has not set one).
    for q in (select column_value v from table(apex_t_varchar2(
                  'CORPORATE|10|Listing and Status', 'CORPORATE|20|Geographic Risk', 'CORPORATE|30|Business Activity',
                  'CORPORATE|40|Ownership and Control', 'CORPORATE|50|Business Activity',
                  'INDIVIDUAL|10|Relationship', 'INDIVIDUAL|20|Geographic Risk', 'INDIVIDUAL|30|Politically Exposed Persons'))) loop
        update xxcmp_questions
           set section_name = regexp_substr(q.v, '[^|]+', 1, 3)
         where questionnaire_code = regexp_substr(q.v, '[^|]+', 1, 1)
           and display_sequence   = to_number(regexp_substr(q.v, '[^|]+', 1, 2))
           and section_name is null;
    end loop;

    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_ddl_pkg.mark_release('R13', 'Release 13: KYC requests and cases (intake, investigation, approval workflows)');
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- release 29: open cases without an assignee go to the approver of their request's first approval step
declare
    l_sgid number;
begin
    select max(workspace_id) into l_sgid from apex_applications where application_id = 134;
    if l_sgid is not null then
        apex_util.set_security_group_id(l_sgid);
    end if;
    xxfnd_vpd_pkg.begin_trusted;
    update xxcmp_cases c
       set c.assigned_to = xxcmp_case_pkg.first_approver(c.request_id)
     where c.assigned_to is null and c.closed_date is null and c.request_id is not null;
    xxfnd_vpd_pkg.end_trusted;
    commit;
exception
    when others then
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/
