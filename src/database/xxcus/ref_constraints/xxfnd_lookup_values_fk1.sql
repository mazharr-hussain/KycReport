alter table xxcus.xxfnd_lookup_values
    add constraint xxfnd_lookup_values_fk1
        foreign key ( lookup_type )
            references xxcus.xxfnd_lookup_types ( lookup_type )
        enable;


-- sqlcl_snapshot {"hash":"34822d0508dd245d20f2c94d3244f78e25cc4887","type":"REF_CONSTRAINT","name":"XXFND_LOOKUP_VALUES_FK1","schemaName":"XXCUS","sxml":""}