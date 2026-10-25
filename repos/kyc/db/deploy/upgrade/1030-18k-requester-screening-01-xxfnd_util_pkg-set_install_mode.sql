--------------------------------------------------------------------------------
-- 18k Requester risk screening (release 99)
--   Create Request step 1 asks the requester questionnaire (risk screening) before the business relationship.
--   Seeds the ownership question of the CORPORATE questionnaire: "Business counterparty ownership structure type",
--   an applicability gate whose answers carry no risk points and do not waive KYC - the KYC rules administrator
--   decides which answers waive KYC (KYC Rules, maker-checker). Draft requests get the question too.
-- Idempotent: the question is added only when missing; an administrator's changes are kept.
--------------------------------------------------------------------------------
declare
    c_text constant varchar2(200) := 'Business counterparty ownership structure type';
    l_q     number;
    l_count pls_integer;

    procedure answer(p_seq in number, p_label in varchar2) is
    begin
        insert into xxcmp_answer_options (question_id, answer_label, risk_points, critical_flag, waiver_qualifying_flag,
                                          display_sequence, approval_status)
        values (l_q, p_label, 0, 'N', 'N', p_seq, 'APPROVED');
    end answer;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select count(*) into l_count from xxcmp_questions where questionnaire_code = 'CORPORATE' and question_text = c_text;
    if l_count = 0 then
        insert into xxcmp_questions (questionnaire_code, question_text, answer_type, gate_question_flag, required_flag,
                                     display_sequence, section_name)
        values ('CORPORATE', c_text, 'SINGLE_SELECT', 'Y', 'Y', 35, 'Ownership and Control')
        returning question_id into l_q;
        answer(10, 'Qatari Fully Owned Entity');
        answer(20, 'Qatari Majority Owned Entity');
        answer(30, 'Qatari Minority Owned Entity');
        answer(40, 'Foreign Owned Entity');
        answer(50, 'Government / Semi-Government Entity');
        answer(60, 'Other');
    end if;
    -- requests not yet submitted answer the question too (submitted requests keep the answers they were decided on)
    insert into xxcmp_request_answers (request_id, case_id, respondent_type, question_id)
    select r.request_id, null, 'REQUESTER', q.question_id
      from xxcmp_requests r
      join xxcmp_questions q on q.questionnaire_code = r.questionnaire_code
     where r.request_status in ('DRAFT', 'INFO_NEEDED')
       and q.questionnaire_code = 'CORPORATE' and q.question_text = c_text and q.enabled_flag = 'Y'
       and not exists (select 1 from xxcmp_request_answers a
                        where a.request_id = r.request_id and a.respondent_type = 'REQUESTER' and a.question_id = q.question_id);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
