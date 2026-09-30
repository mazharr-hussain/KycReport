alter table xxcus.xxfnd_storage_config
    add constraint xxfnd_storage_config_fk3
        foreign key ( endpoint_code )
            references xxcus.xxfnd_integration_endpoints ( endpoint_code )
        enable;


-- sqlcl_snapshot {"hash":"1874d47820b96d58743e07a8949a9eefa6a24c4a","type":"REF_CONSTRAINT","name":"XXFND_STORAGE_CONFIG_FK3","schemaName":"XXCUS","sxml":""}