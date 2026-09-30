alter table xxcus.xxcmp_party_relationships
    add constraint xxcmp_party_rel_fk1
        foreign key ( subject_party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"12c532cbd1413b0f21084bbdb56a852422009422","type":"REF_CONSTRAINT","name":"XXCMP_PARTY_REL_FK1","schemaName":"XXCUS","sxml":""}