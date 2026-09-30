alter table xxcus.xxfnd_attachment_blk_entities
    add constraint xxfnd_att_blk_entities_fk2
        foreign key ( entity_name )
            references xxcus.xxfnd_document_entities ( entity_name )
        enable;


-- sqlcl_snapshot {"hash":"dea59e6a985f097d5dd48b5be8005de0a6d16899","type":"REF_CONSTRAINT","name":"XXFND_ATT_BLK_ENTITIES_FK2","schemaName":"XXCUS","sxml":""}