alter table xxcus.xxfnd_doc_category_usages
    add constraint xxfnd_doc_category_usages_fk1
        foreign key ( function_code )
            references xxcus.xxfnd_attachment_functions ( function_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"862728a6fcdf79ef290edc591ea0ce2a14d129b9","type":"REF_CONSTRAINT","name":"XXFND_DOC_CATEGORY_USAGES_FK1","schemaName":"XXCUS","sxml":""}