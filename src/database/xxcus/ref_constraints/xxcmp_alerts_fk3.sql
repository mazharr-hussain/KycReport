alter table xxcus.xxcmp_alerts
    add constraint xxcmp_alerts_fk3
        foreign key ( case_id )
            references xxcus.xxcmp_cases ( case_id )
        enable;


-- sqlcl_snapshot {"hash":"a22236cccb7f7d1ad021ca63c34a51c5b35cf192","type":"REF_CONSTRAINT","name":"XXCMP_ALERTS_FK3","schemaName":"XXCUS","sxml":""}