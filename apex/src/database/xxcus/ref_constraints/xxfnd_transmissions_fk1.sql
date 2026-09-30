alter table xxcus.xxfnd_transmissions
    add constraint xxfnd_transmissions_fk1
        foreign key ( endpoint_code )
            references xxcus.xxfnd_integration_endpoints ( endpoint_code )
        enable;


-- sqlcl_snapshot {"hash":"43c71d0ee90ce1058da2b8e73888d7a75d2d8f56","type":"REF_CONSTRAINT","name":"XXFND_TRANSMISSIONS_FK1","schemaName":"XXCUS","sxml":""}