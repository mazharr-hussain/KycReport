alter table xxcus.xxfnd_lookup_values
    add constraint xxfnd_lookup_values_fk2
        foreign key ( parent_lookup_type,
                      parent_lookup_code )
            references xxcus.xxfnd_lookup_values ( lookup_type,
                                                   lookup_code )
        enable;


-- sqlcl_snapshot {"hash":"ce35e8a15062017a2e908457295b5a53a8101db0","type":"REF_CONSTRAINT","name":"XXFND_LOOKUP_VALUES_FK2","schemaName":"XXCUS","sxml":""}