alter table xxcus.xxcmp_answer_options
    add constraint xxcmp_answer_options_fk2
        foreign key ( lookup_type,
                      lookup_code )
            references xxcus.xxfnd_lookup_values ( lookup_type,
                                                   lookup_code )
        enable;


-- sqlcl_snapshot {"hash":"15d3bc0354dedaf3645035917f563384d40181b3","type":"REF_CONSTRAINT","name":"XXCMP_ANSWER_OPTIONS_FK2","schemaName":"XXCUS","sxml":""}