alter table xxcus.xxfnd_storage_config
    add constraint xxfnd_storage_config_fk2
        foreign key ( category_code )
            references xxcus.xxfnd_document_categories ( category_code )
        enable;


-- sqlcl_snapshot {"hash":"c0a6ed13a00f96354436b4d2ff124cdd645f5577","type":"REF_CONSTRAINT","name":"XXFND_STORAGE_CONFIG_FK2","schemaName":"XXCUS","sxml":""}