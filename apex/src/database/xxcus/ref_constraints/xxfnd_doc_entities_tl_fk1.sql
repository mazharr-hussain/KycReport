alter table xxcus.xxfnd_document_entities_tl
    add constraint xxfnd_doc_entities_tl_fk1
        foreign key ( entity_name )
            references xxcus.xxfnd_document_entities ( entity_name )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"0f606ee4c6e6d3720813e5eba62ff37dd0b3bc0c","type":"REF_CONSTRAINT","name":"XXFND_DOC_ENTITIES_TL_FK1","schemaName":"XXCUS","sxml":""}