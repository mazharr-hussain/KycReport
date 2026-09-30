alter table xxcus.xxfnd_storage_config
    add constraint xxfnd_storage_config_fk1
        foreign key ( entity_name )
            references xxcus.xxfnd_document_entities ( entity_name )
        enable;


-- sqlcl_snapshot {"hash":"7022defdb8fea504cb974f8b1cf99aef894353d8","type":"REF_CONSTRAINT","name":"XXFND_STORAGE_CONFIG_FK1","schemaName":"XXCUS","sxml":""}