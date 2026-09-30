alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_fk1
        foreign key ( descriptive_flexfield_code,
                      context_code )
            references xxcus.xxfnd_df_contexts ( descriptive_flexfield_code,
                                                 context_code )
        enable;


-- sqlcl_snapshot {"hash":"a65a214539578d313ca546092c280beb9183d570","type":"REF_CONSTRAINT","name":"XXFND_DF_SEGMENTS_FK1","schemaName":"XXCUS","sxml":""}