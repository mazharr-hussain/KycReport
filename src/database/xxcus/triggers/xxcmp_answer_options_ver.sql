create or replace editionable trigger xxcus.xxcmp_answer_options_ver after
    update of approval_status on xxcus.xxcmp_answer_options
    for each row
    when ( new.approval_status = 'APPROVED'
           and old.approval_status <> 'APPROVED' )
begin
    update xxcmp_questionnaires q
    set
        q.current_version_number = q.current_version_number + 1
    where
        q.questionnaire_code = (
            select
                questionnaire_code
            from
                xxcmp_questions
            where
                question_id = :new.question_id
        );

end;
/

alter trigger xxcus.xxcmp_answer_options_ver enable;


-- sqlcl_snapshot {"hash":"749568bc72ae7beb5c80a6cd89898cc535b06e82","type":"TRIGGER","name":"XXCMP_ANSWER_OPTIONS_VER","schemaName":"XXCUS","sxml":""}