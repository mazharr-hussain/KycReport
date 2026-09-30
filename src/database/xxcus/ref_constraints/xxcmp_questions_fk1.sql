alter table xxcus.xxcmp_questions
    add constraint xxcmp_questions_fk1
        foreign key ( questionnaire_code )
            references xxcus.xxcmp_questionnaires ( questionnaire_code )
        enable;


-- sqlcl_snapshot {"hash":"f7c5eb9b4b1d6d63da3b4c59a2118eb6da02a594","type":"REF_CONSTRAINT","name":"XXCMP_QUESTIONS_FK1","schemaName":"XXCUS","sxml":""}