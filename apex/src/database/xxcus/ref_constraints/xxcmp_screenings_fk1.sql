alter table xxcus.xxcmp_screenings
    add constraint xxcmp_screenings_fk1
        foreign key ( case_id )
            references xxcus.xxcmp_cases ( case_id )
        enable;


-- sqlcl_snapshot {"hash":"eabebf33491a891f2caf4ee30bdd6b88df8cfd5d","type":"REF_CONSTRAINT","name":"XXCMP_SCREENINGS_FK1","schemaName":"XXCUS","sxml":""}