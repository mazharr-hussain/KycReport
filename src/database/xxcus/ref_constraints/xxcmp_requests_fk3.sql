alter table xxcus.xxcmp_requests
    add constraint xxcmp_requests_fk3
        foreign key ( questionnaire_code )
            references xxcus.xxcmp_questionnaires ( questionnaire_code )
        enable;


-- sqlcl_snapshot {"hash":"cbd44f1eab7b706a368e592d90e856e776ca4fc3","type":"REF_CONSTRAINT","name":"XXCMP_REQUESTS_FK3","schemaName":"XXCUS","sxml":""}