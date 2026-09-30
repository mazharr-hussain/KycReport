alter table xxcus.xxcmp_ubo_determinations
    add constraint xxcmp_ubo_determinations_fk2
        foreign key ( owner_party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"48c627b4fac1e7c6d3e4eaabb0167f17397d1512","type":"REF_CONSTRAINT","name":"XXCMP_UBO_DETERMINATIONS_FK2","schemaName":"XXCUS","sxml":""}