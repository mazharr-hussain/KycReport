alter table xxcus.xxfnd_documents_tl
    add constraint xxfnd_documents_tl_fk1
        foreign key ( document_id )
            references xxcus.xxfnd_documents ( document_id )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"8664daa54d5f489767d6756aa32d25ed1c70dfde","type":"REF_CONSTRAINT","name":"XXFND_DOCUMENTS_TL_FK1","schemaName":"XXCUS","sxml":""}