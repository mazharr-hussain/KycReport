alter table xxcus.xxfnd_df_segments_tl
    add constraint xxfnd_df_segments_tl_fk1
        foreign key ( descriptive_flexfield_code,
                      context_code,
                      segment_code )
            references xxcus.xxfnd_df_segments ( descriptive_flexfield_code,
                                                 context_code,
                                                 segment_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"2a9b3ec7a7aff18429904412027943cc0927edd0","type":"REF_CONSTRAINT","name":"XXFND_DF_SEGMENTS_TL_FK1","schemaName":"XXCUS","sxml":""}