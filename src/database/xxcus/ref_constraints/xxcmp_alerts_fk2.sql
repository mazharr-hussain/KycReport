alter table xxcus.xxcmp_alerts
    add constraint xxcmp_alerts_fk2
        foreign key ( party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"fb964f5c99eb7f6fa629b434a68ba75dc9540993","type":"REF_CONSTRAINT","name":"XXCMP_ALERTS_FK2","schemaName":"XXCUS","sxml":""}