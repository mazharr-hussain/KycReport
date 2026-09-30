alter table xxcus.xxfnd_privileges
    add constraint xxfnd_privileges_fk1
        foreign key ( feature_code )
            references xxcus.xxfnd_features ( feature_code )
        enable;


-- sqlcl_snapshot {"hash":"b8be1ba4e2233af5776a3c11ad63c05a6197afe9","type":"REF_CONSTRAINT","name":"XXFND_PRIVILEGES_FK1","schemaName":"XXCUS","sxml":""}