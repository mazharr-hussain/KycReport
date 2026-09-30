alter table xxcus.xxfnd_sod_rules
    add constraint xxfnd_sod_rules_fk1
        foreign key ( role_code_1 )
            references xxcus.xxfnd_roles ( role_code )
        enable;


-- sqlcl_snapshot {"hash":"4b55c9e5ad5408bd1d46a57e8b196940af4d5a1a","type":"REF_CONSTRAINT","name":"XXFND_SOD_RULES_FK1","schemaName":"XXCUS","sxml":""}