alter table xxcus.xxcmp_rfis
    add constraint xxcmp_rfis_fk1
        foreign key ( entity_name )
            references xxcus.xxfnd_document_entities ( entity_name )
        enable;


-- sqlcl_snapshot {"hash":"a61a54d6aa09258c05a1d05873c0d6a165213ca2","type":"REF_CONSTRAINT","name":"XXCMP_RFIS_FK1","schemaName":"XXCUS","sxml":""}