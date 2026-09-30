alter table xxcus.xxfnd_attached_documents
    add constraint xxfnd_attached_documents_fk2
        foreign key ( entity_name )
            references xxcus.xxfnd_document_entities ( entity_name )
        enable;


-- sqlcl_snapshot {"hash":"54c1930abb817e6cdfdd7f17966661c6d2c903fc","type":"REF_CONSTRAINT","name":"XXFND_ATTACHED_DOCUMENTS_FK2","schemaName":"XXCUS","sxml":""}