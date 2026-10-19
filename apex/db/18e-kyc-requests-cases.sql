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

--------------------------------------------------------------------------------
-- release 48: the view of the pending changes of the KYC configuration tables (answer options are approved per
-- question, rules row by row); release 87: the tables are registered in COMMON by 18h
--------------------------------------------------------------------------------
create or replace view xxcmp_config_changes_v as
select 'XXCMP_QUESTIONS:' || q.question_id                                   detail_pk,
       'Risk scoring answers'                                                 change_type,
       q.questionnaire_code || ' / ' || substr(q.question_text, 1, 200)       change_title,
       listagg(nvl(ao.answer_label, ao.lookup_code) || ': ' || ao.risk_points || ' points'
                 || case when ao.critical_flag = 'Y' then ', critical' end
                 || case when ao.waiver_qualifying_flag = 'Y' then ', waiver' end, '; ')
         within group (order by ao.display_sequence)                          change_summary,
       max(ao.last_updated_by)                                                submitted_by,
       max(ao.last_update_date)                                               submitted_date
  from xxcmp_answer_options ao
  join xxcmp_questions q on q.question_id = ao.question_id
 where ao.approval_status = 'PENDING_APPROVAL'
 group by q.question_id, q.questionnaire_code, q.question_text
union all
select 'XXCMP_ATTACHMENT_RULES:' || r.attachment_rule_id,
       'Mandatory document rule',
       r.entity_name || ' / ' || r.category_code,
       nvl(r.jurisdiction, 'any jurisdiction') || ' / ' || nvl(r.entity_type, 'any entity type')
         || ' / ' || case r.mandatory_flag when 'Y' then 'mandatory' else 'optional' end,
       r.last_updated_by,
       r.last_update_date
  from xxcmp_attachment_rules r
 where r.approval_status = 'PENDING_APPROVAL'
union all
-- release 74 (R16): risk model changes, one approval per table
select 'XXCMP_RISK_FACTOR_SET:KYC', 'Risk model factors', 'Risk factors',
       listagg(f.factor_name || ': ' || f.points || case when f.enabled_flag = 'N' then ' (off)' end
               || nvl2(f.force_tier, ', forces ' || f.force_tier, null), '; ') within group (order by f.display_sequence),
       max(f.last_updated_by), max(f.last_update_date)
  from xxcmp_risk_factors f
 where f.approval_status = 'PENDING_APPROVAL'
having count(*) > 0
union all
select 'XXCMP_RISK_COUNTRY_SET:KYC', 'Risk model country lists', 'Country lists',
       listagg(c.list_code || ' ' || c.country_code || case when c.enabled_flag = 'N' then ' (removed)' end, '; ')
         within group (order by c.list_code, c.country_code),
       max(c.last_updated_by), max(c.last_update_date)
  from xxcmp_risk_countries c
 where c.approval_status = 'PENDING_APPROVAL'
having count(*) > 0
union all
select 'XXCMP_RISK_TIER_SET:KYC', 'Risk model tiers', 'Risk tiers',
       listagg(t.risk_tier || ' from ' || t.min_score || ', review ' || t.review_months || ' months', '; ')
         within group (order by t.min_score),
       max(t.last_updated_by), max(t.last_update_date)
  from xxcmp_risk_tiers t
 where t.approval_status = 'PENDING_APPROVAL'
having count(*) > 0;
comment on table xxcmp_config_changes_v is 'KYC configuration changes waiting for approval (registered changes view in XXFND_CONFIG_TABLES).';

-- release 74: the messages the party, request and case components raise (message catalogue, COMMON 09f); a text
-- Compliance changed is kept
begin
    xxfnd_error_pkg.register_message('KYC_PARTY_CREATE_NOT_ALLOWED', 'You are not allowed to create parties.', -20701);
    xxfnd_error_pkg.register_message('KYC_PARTY_CHANGE_NOT_ALLOWED', 'You are not allowed to change parties.', -20706);
    xxfnd_error_pkg.register_message('KYC_PARTY_DISABLED', 'A disabled or merged party cannot be changed.', -20707);
    xxfnd_error_pkg.register_message('KYC_PARTY_THIS_NOT_ALLOWED', 'You are not allowed to change this party.', -20706);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_NOT_ALLOWED', 'Only Compliance can merge parties.', -20711);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_TARGET', 'Choose another party to merge into.', -20712);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_TYPE', 'An organisation cannot be merged into an individual, or the reverse.', -20713);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_DISABLED', 'Both parties must be enabled.', -20714);
    xxfnd_error_pkg.register_message('KYC_REQUEST_LOCKED', 'Request {1} can no longer be changed.', -20612);
    xxfnd_error_pkg.register_message('KYC_REQUEST_PARTY_FIXED', 'The counterparty of a submitted request cannot be replaced.', -20617);
    xxfnd_error_pkg.register_message('KYC_REQUEST_PARTY_APPROVED', 'The party of this request has been approved: Compliance maintains it.', -20618);
    xxfnd_error_pkg.register_message('KYC_REQUEST_ANSWERS_LOCKED', 'The request has been submitted; its answers can no longer be changed.', -20613);
    xxfnd_error_pkg.register_message('KYC_REQUEST_QUESTION_UNKNOWN', 'Question {1} does not belong to this request.', -20614);
    xxfnd_error_pkg.register_message('KYC_REQUEST_OPTION_UNKNOWN', 'Answer {1} is not an option of question {2}.', -20615);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NUMBER_EXPECTED', 'Enter a number for: {1}', -20616);
    xxfnd_error_pkg.register_message('KYC_REQUEST_INFO_TEXT', 'Enter the information you need from the requester.', -20625);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NOT_IN_APPROVAL', 'Request {1} is not waiting for approval.', -20625);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NOT_APPROVER', 'You are not an approver of request {1}.', -20625);
    -- release 76: requesting departments from data security
    xxfnd_error_pkg.register_message('KYC_REQUEST_NO_DEPARTMENT', 'No requesting department is set up for you. Ask the administrator to give you a Requesting Entity role.', -20626);
    -- release 95 (COMMON 96 security model): the department comes with the requesting entity role (its Data Access Values)
    xxfnd_error_pkg.register_message('KYC_REQUEST_NO_ENTITY', 'You may not raise requests for any department yet. Ask the administrator to give you a requesting entity role (e.g. Requesting Entity1) with your department in its data access values.', -20626);
    xxfnd_error_pkg.register_message('KYC_REQUEST_DEPT_NOT_ALLOWED', 'You cannot raise requests for {1}. Choose one of your departments.', -20626);
    xxfnd_error_pkg.register_message('KYC_CASE_REASSIGN_NOT_ALLOWED', 'Only a case under investigation can be reassigned, by Compliance management or its assignee.', -20611);
    xxfnd_error_pkg.register_message('KYC_CASE_OFFICER_REQUIRED', 'Select the officer.', -20611);
    -- release 75: the officer chosen for a case must be an active Compliance officer, manager or head of Compliance
    xxfnd_error_pkg.register_message('KYC_CASE_OFFICER_INVALID', 'Choose an active Compliance officer, manager or head of Compliance.', -20619);
    xxfnd_error_pkg.register_message('KYC_CASE_WITHDRAW_NOT_ALLOWED', 'Only a case waiting for approval can be withdrawn, by its officer or Compliance management.', -20615);
    xxfnd_error_pkg.register_message('KYC_CASE_WITHDRAW_REASON', 'Enter the reason for withdrawing the case from approval.', -20615);
    xxfnd_error_pkg.register_message('KYC_CASE_NO_MATRIX_ROW', 'The approval matrix has no row for risk tier {1}.', -20612);
    xxfnd_error_pkg.register_message('KYC_CASE_CONTACT_NO_EMAIL', 'The contact person has no e-mail address: add one before sending the request.', -20509);
    xxfnd_error_pkg.register_message('KYC_CASE_FIU_FILING', 'Enter the goAML reference and the date the report was filed.', -20616);
    xxfnd_error_pkg.register_message('KYC_CASE_FUNDS_EVIDENCE', 'Record the evidence seen before marking the source as verified.', -20617);
    commit;
end;
/
