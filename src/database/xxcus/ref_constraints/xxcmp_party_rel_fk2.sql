alter table xxcus.xxcmp_party_relationships
    add constraint xxcmp_party_rel_fk2
        foreign key ( object_party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"0e1904901a628bbde5b60d60ec5762994833adca","type":"REF_CONSTRAINT","name":"XXCMP_PARTY_REL_FK2","schemaName":"XXCUS","sxml":""}