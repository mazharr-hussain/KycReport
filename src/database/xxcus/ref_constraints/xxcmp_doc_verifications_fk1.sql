alter table xxcus.xxcmp_doc_verifications
    add constraint xxcmp_doc_verifications_fk1
        foreign key ( case_id )
            references xxcus.xxcmp_cases ( case_id )
        enable;


-- sqlcl_snapshot {"hash":"91653b12634f12fca32dc0400926b9e9fe3c14f6","type":"REF_CONSTRAINT","name":"XXCMP_DOC_VERIFICATIONS_FK1","schemaName":"XXCUS","sxml":""}