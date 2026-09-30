alter table xxcus.xxcmp_questions_tl
    add constraint xxcmp_questions_tl_fk1
        foreign key ( question_id )
            references xxcus.xxcmp_questions ( question_id )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"1dad79ea4af06ae6d18273942e58cd1b4d066454","type":"REF_CONSTRAINT","name":"XXCMP_QUESTIONS_TL_FK1","schemaName":"XXCUS","sxml":""}