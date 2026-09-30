alter table xxcus.xxcmp_ubo_determinations
    add constraint xxcmp_ubo_determinations_fk1
        foreign key ( case_id )
            references xxcus.xxcmp_cases ( case_id )
        enable;


-- sqlcl_snapshot {"hash":"e244c6b6c66096b7999b514ae926c35de89f80e3","type":"REF_CONSTRAINT","name":"XXCMP_UBO_DETERMINATIONS_FK1","schemaName":"XXCUS","sxml":""}