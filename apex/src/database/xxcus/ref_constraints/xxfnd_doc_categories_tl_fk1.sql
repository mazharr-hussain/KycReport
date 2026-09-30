alter table xxcus.xxfnd_document_categories_tl
    add constraint xxfnd_doc_categories_tl_fk1
        foreign key ( category_code )
            references xxcus.xxfnd_document_categories ( category_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"4bfe2a6b6c07a67a50e359e658b2ba328728a728","type":"REF_CONSTRAINT","name":"XXFND_DOC_CATEGORIES_TL_FK1","schemaName":"XXCUS","sxml":""}