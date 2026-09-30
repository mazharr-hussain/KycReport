alter table xxcus.xxfnd_df_flexfields_tl
    add constraint xxfnd_df_flexfields_tl_fk1
        foreign key ( descriptive_flexfield_code )
            references xxcus.xxfnd_df_flexfields ( descriptive_flexfield_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"a8dc83be19c0032ef2459da91916afa40f4e4b6a","type":"REF_CONSTRAINT","name":"XXFND_DF_FLEXFIELDS_TL_FK1","schemaName":"XXCUS","sxml":""}