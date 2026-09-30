alter table xxcus.xxfnd_documents
    add constraint xxfnd_documents_fk3
        foreign key ( storage_config_id )
            references xxcus.xxfnd_storage_config ( storage_config_id )
        enable;


-- sqlcl_snapshot {"hash":"19555119d11f7aa5e7a1ddc71cc467cfc058b3b9","type":"REF_CONSTRAINT","name":"XXFND_DOCUMENTS_FK3","schemaName":"XXCUS","sxml":""}