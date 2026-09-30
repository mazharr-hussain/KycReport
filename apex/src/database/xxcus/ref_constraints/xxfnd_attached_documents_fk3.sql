alter table xxcus.xxfnd_attached_documents
    add constraint xxfnd_attached_documents_fk3
        foreign key ( category_code )
            references xxcus.xxfnd_document_categories ( category_code )
        enable;


-- sqlcl_snapshot {"hash":"6d2d1c667e202379cd99a21a662ad66b4b055b47","type":"REF_CONSTRAINT","name":"XXFND_ATTACHED_DOCUMENTS_FK3","schemaName":"XXCUS","sxml":""}