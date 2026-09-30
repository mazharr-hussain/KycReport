alter table xxcus.xxcmp_case_decisions
    add constraint xxcmp_case_decisions_fk1
        foreign key ( case_id )
            references xxcus.xxcmp_cases ( case_id )
        enable;


-- sqlcl_snapshot {"hash":"7a67137f6455dc58451450c2b08c859991a0ddf6","type":"REF_CONSTRAINT","name":"XXCMP_CASE_DECISIONS_FK1","schemaName":"XXCUS","sxml":""}