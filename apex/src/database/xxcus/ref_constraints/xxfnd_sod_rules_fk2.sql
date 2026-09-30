alter table xxcus.xxfnd_sod_rules
    add constraint xxfnd_sod_rules_fk2
        foreign key ( role_code_2 )
            references xxcus.xxfnd_roles ( role_code )
        enable;


-- sqlcl_snapshot {"hash":"11504287563a428f0771636a7792f60520e28a21","type":"REF_CONSTRAINT","name":"XXFND_SOD_RULES_FK2","schemaName":"XXCUS","sxml":""}