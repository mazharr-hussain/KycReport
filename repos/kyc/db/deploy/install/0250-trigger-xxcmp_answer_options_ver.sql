
-- release 54: XXFND_INT_PURPOSES_MC (shared table) is created by script 09c (COMMON).

-- An approved scoring change raises the questionnaire version, so responses
-- record which version they were scored against.
create or replace trigger xxcmp_answer_options_ver
    after update of approval_status on xxcmp_answer_options
    for each row
    when (new.approval_status = 'APPROVED' and old.approval_status <> 'APPROVED')
begin
    update xxcmp_questionnaires q
       set q.current_version_number = q.current_version_number + 1
     where q.questionnaire_code = (select questionnaire_code from xxcmp_questions where question_id = :new.question_id);
end;
/
