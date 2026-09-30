alter table xxcus.xxcmp_cases
    add constraint xxcmp_cases_fk2
        foreign key ( party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"dbfcc3b7a63d6acd3e412cefe04411acd9d3ad2a","type":"REF_CONSTRAINT","name":"XXCMP_CASES_FK2","schemaName":"XXCUS","sxml":""}