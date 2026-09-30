alter table xxcus.xxfnd_value_sets
    add constraint xxfnd_value_sets_fk2
        foreign key ( parent_value_set_code )
            references xxcus.xxfnd_value_sets ( value_set_code )
        enable;


-- sqlcl_snapshot {"hash":"01c73cae8b365384f77c83ce09853907f65bcbaa","type":"REF_CONSTRAINT","name":"XXFND_VALUE_SETS_FK2","schemaName":"XXCUS","sxml":""}