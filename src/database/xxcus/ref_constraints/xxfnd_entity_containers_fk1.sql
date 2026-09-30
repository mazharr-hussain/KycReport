alter table xxcus.xxfnd_entity_containers
    add constraint xxfnd_entity_containers_fk1
        foreign key ( entity_name )
            references xxcus.xxfnd_document_entities ( entity_name )
        enable;


-- sqlcl_snapshot {"hash":"43b685a4182dc4dbd5ccae6cf3c580a97fcaa23d","type":"REF_CONSTRAINT","name":"XXFND_ENTITY_CONTAINERS_FK1","schemaName":"XXCUS","sxml":""}