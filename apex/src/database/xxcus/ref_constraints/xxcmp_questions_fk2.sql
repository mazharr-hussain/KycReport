alter table xxcus.xxcmp_questions
    add constraint xxcmp_questions_fk2
        foreign key ( lookup_type )
            references xxcus.xxfnd_lookup_types ( lookup_type )
        enable;


-- sqlcl_snapshot {"hash":"c5fd928831dafe9a7d69f565bb3bfb9abc998a9b","type":"REF_CONSTRAINT","name":"XXCMP_QUESTIONS_FK2","schemaName":"XXCUS","sxml":""}