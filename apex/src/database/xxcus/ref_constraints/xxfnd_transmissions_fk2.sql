alter table xxcus.xxfnd_transmissions
    add constraint xxfnd_transmissions_fk2
        foreign key ( purpose_code )
            references xxcus.xxfnd_integration_purposes ( purpose_code )
        enable;


-- sqlcl_snapshot {"hash":"c1d1060465760bb65518010751d41b66378d3d97","type":"REF_CONSTRAINT","name":"XXFND_TRANSMISSIONS_FK2","schemaName":"XXCUS","sxml":""}