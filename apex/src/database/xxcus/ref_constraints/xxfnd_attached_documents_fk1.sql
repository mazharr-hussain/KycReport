alter table xxcus.xxfnd_attached_documents
    add constraint xxfnd_attached_documents_fk1
        foreign key ( document_id )
            references xxcus.xxfnd_documents ( document_id )
        enable;


-- sqlcl_snapshot {"hash":"1cd6a33d24988d371a8ed91de98245269e02575c","type":"REF_CONSTRAINT","name":"XXFND_ATTACHED_DOCUMENTS_FK1","schemaName":"XXCUS","sxml":""}