alter table xxcus.xxcmp_answer_options
    add constraint xxcmp_answer_options_fk1
        foreign key ( question_id )
            references xxcus.xxcmp_questions ( question_id )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"8e4a0f8cde8c7adbc9100d20b1d5c5859c5b85ea","type":"REF_CONSTRAINT","name":"XXCMP_ANSWER_OPTIONS_FK1","schemaName":"XXCUS","sxml":""}