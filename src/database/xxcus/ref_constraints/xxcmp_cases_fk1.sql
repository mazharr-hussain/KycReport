alter table xxcus.xxcmp_cases
    add constraint xxcmp_cases_fk1
        foreign key ( request_id )
            references xxcus.xxcmp_requests ( request_id )
        enable;


-- sqlcl_snapshot {"hash":"56d3f5570aa54e89644834d6f8a3a5edf68a532a","type":"REF_CONSTRAINT","name":"XXCMP_CASES_FK1","schemaName":"XXCUS","sxml":""}