alter table xxcus.xxcmp_attachment_rules
    add constraint xxcmp_attachment_rules_fk2
        foreign key ( category_code )
            references xxcus.xxfnd_document_categories ( category_code )
        enable;


-- sqlcl_snapshot {"hash":"827503aaaa2b081f76b16525adf1e532e0fd5007","type":"REF_CONSTRAINT","name":"XXCMP_ATTACHMENT_RULES_FK2","schemaName":"XXCUS","sxml":""}