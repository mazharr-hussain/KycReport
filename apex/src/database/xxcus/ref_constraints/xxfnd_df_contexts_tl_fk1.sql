alter table xxcus.xxfnd_df_contexts_tl
    add constraint xxfnd_df_contexts_tl_fk1
        foreign key ( descriptive_flexfield_code,
                      context_code )
            references xxcus.xxfnd_df_contexts ( descriptive_flexfield_code,
                                                 context_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"7d7b9a605f823572c3e57fdbdc9c6d60698e012f","type":"REF_CONSTRAINT","name":"XXFND_DF_CONTEXTS_TL_FK1","schemaName":"XXCUS","sxml":""}