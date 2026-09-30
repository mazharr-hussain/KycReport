alter table xxcus.xxfnd_df_contexts
    add constraint xxfnd_df_contexts_fk1
        foreign key ( descriptive_flexfield_code )
            references xxcus.xxfnd_df_flexfields ( descriptive_flexfield_code )
        enable;


-- sqlcl_snapshot {"hash":"47e43afac0433d293f9009f57e35bde6100bd2a8","type":"REF_CONSTRAINT","name":"XXFND_DF_CONTEXTS_FK1","schemaName":"XXCUS","sxml":""}