alter table xxcus.xxfnd_documents
    add constraint xxfnd_documents_fk1
        foreign key ( category_code )
            references xxcus.xxfnd_document_categories ( category_code )
        enable;


-- sqlcl_snapshot {"hash":"32f09bef72e9b86c2bcfa29c82dff52428531604","type":"REF_CONSTRAINT","name":"XXFND_DOCUMENTS_FK1","schemaName":"XXCUS","sxml":""}