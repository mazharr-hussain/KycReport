alter table xxcus.xxfnd_value_sets
    add constraint xxfnd_value_sets_fk1
        foreign key ( lookup_type )
            references xxcus.xxfnd_lookup_types ( lookup_type )
        enable;


-- sqlcl_snapshot {"hash":"bb5fa17831ecdfa0c2b9547e5bd28f2f197da32f","type":"REF_CONSTRAINT","name":"XXFND_VALUE_SETS_FK1","schemaName":"XXCUS","sxml":""}