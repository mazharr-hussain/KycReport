alter table xxcus.xxfnd_doc_category_usages
    add constraint xxfnd_doc_category_usages_fk2
        foreign key ( category_code )
            references xxcus.xxfnd_document_categories ( category_code )
        enable;


-- sqlcl_snapshot {"hash":"a34b59c0d1d8ffc95a48f14dfa8327fdfbc4727b","type":"REF_CONSTRAINT","name":"XXFND_DOC_CATEGORY_USAGES_FK2","schemaName":"XXCUS","sxml":""}