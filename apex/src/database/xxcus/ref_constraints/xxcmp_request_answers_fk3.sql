alter table xxcus.xxcmp_request_answers
    add constraint xxcmp_request_answers_fk3
        foreign key ( question_id )
            references xxcus.xxcmp_questions ( question_id )
        enable;


-- sqlcl_snapshot {"hash":"2ba534f561b5980440195243783b0f73213b6583","type":"REF_CONSTRAINT","name":"XXCMP_REQUEST_ANSWERS_FK3","schemaName":"XXCUS","sxml":""}