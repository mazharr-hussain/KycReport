alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_fk2
        foreign key ( value_set_code )
            references xxcus.xxfnd_value_sets ( value_set_code )
        enable;


-- sqlcl_snapshot {"hash":"806d207e2b0a4425768c6009c14e2476f54a3b94","type":"REF_CONSTRAINT","name":"XXFND_DF_SEGMENTS_FK2","schemaName":"XXCUS","sxml":""}