alter table xxcus.xxfnd_lookup_values_tl
    add constraint xxfnd_lookup_values_tl_fk1
        foreign key ( lookup_type,
                      lookup_code )
            references xxcus.xxfnd_lookup_values ( lookup_type,
                                                   lookup_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"ac15c2f9415f1a4857b291cc7f2aba3833e9574b","type":"REF_CONSTRAINT","name":"XXFND_LOOKUP_VALUES_TL_FK1","schemaName":"XXCUS","sxml":""}