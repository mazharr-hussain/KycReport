alter table xxcus.xxcmp_attachment_rules
    add constraint xxcmp_attachment_rules_fk1
        foreign key ( entity_name )
            references xxcus.xxfnd_document_entities ( entity_name )
        enable;


-- sqlcl_snapshot {"hash":"19eb205b95859d1165da4bc7aa679fe7092915ca","type":"REF_CONSTRAINT","name":"XXCMP_ATTACHMENT_RULES_FK1","schemaName":"XXCUS","sxml":""}