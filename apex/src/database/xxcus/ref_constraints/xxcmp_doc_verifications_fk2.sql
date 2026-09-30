alter table xxcus.xxcmp_doc_verifications
    add constraint xxcmp_doc_verifications_fk2
        foreign key ( attached_document_id )
            references xxcus.xxfnd_attached_documents ( attached_document_id )
        enable;


-- sqlcl_snapshot {"hash":"f893def519ca41a6a50395f2974f825d2e377172","type":"REF_CONSTRAINT","name":"XXCMP_DOC_VERIFICATIONS_FK2","schemaName":"XXCUS","sxml":""}