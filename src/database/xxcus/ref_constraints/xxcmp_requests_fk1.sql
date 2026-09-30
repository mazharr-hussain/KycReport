alter table xxcus.xxcmp_requests
    add constraint xxcmp_requests_fk1
        foreign key ( party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"79c7fa0d5f2a22c69013be89487bdbba64ad0416","type":"REF_CONSTRAINT","name":"XXCMP_REQUESTS_FK1","schemaName":"XXCUS","sxml":""}