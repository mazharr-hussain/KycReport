alter table xxcus.xxfnd_documents
    add constraint xxfnd_documents_fk2
        foreign key ( base_document_id )
            references xxcus.xxfnd_documents ( document_id )
        enable;


-- sqlcl_snapshot {"hash":"49e4be21594cd803bf7ffd4c8ee7ab132760773f","type":"REF_CONSTRAINT","name":"XXFND_DOCUMENTS_FK2","schemaName":"XXCUS","sxml":""}