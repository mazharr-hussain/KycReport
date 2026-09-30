alter table xxcus.xxcmp_request_answers
    add constraint xxcmp_request_answers_fk2
        foreign key ( case_id )
            references xxcus.xxcmp_cases ( case_id )
        enable;


-- sqlcl_snapshot {"hash":"7d15fe728c88a01c9f19022826d124689f5945b6","type":"REF_CONSTRAINT","name":"XXCMP_REQUEST_ANSWERS_FK2","schemaName":"XXCUS","sxml":""}