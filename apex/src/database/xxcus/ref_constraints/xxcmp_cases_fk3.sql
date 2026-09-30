alter table xxcus.xxcmp_cases
    add constraint xxcmp_cases_fk3
        foreign key ( parent_case_id )
            references xxcus.xxcmp_cases ( case_id )
        enable;


-- sqlcl_snapshot {"hash":"383f9ef4863b8de503cb54fe5564db845f95c7c3","type":"REF_CONSTRAINT","name":"XXCMP_CASES_FK3","schemaName":"XXCUS","sxml":""}