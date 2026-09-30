alter table xxcus.xxfnd_integration_purposes
    add constraint xxfnd_int_purposes_fk1
        foreign key ( endpoint_code )
            references xxcus.xxfnd_integration_endpoints ( endpoint_code )
        enable;


-- sqlcl_snapshot {"hash":"a9605bf3c6957c51459daa9ff515f4b799cd3ad3","type":"REF_CONSTRAINT","name":"XXFND_INT_PURPOSES_FK1","schemaName":"XXCUS","sxml":""}