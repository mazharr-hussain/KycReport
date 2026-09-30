alter table xxcus.xxfnd_entity_containers
    add constraint xxfnd_entity_containers_fk2
        foreign key ( storage_config_id )
            references xxcus.xxfnd_storage_config ( storage_config_id )
        enable;


-- sqlcl_snapshot {"hash":"3d82d9fd1781418b66821724a245255852c6f796","type":"REF_CONSTRAINT","name":"XXFND_ENTITY_CONTAINERS_FK2","schemaName":"XXCUS","sxml":""}