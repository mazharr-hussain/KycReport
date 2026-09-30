alter table xxcus.xxfnd_data_security_rules
    add constraint xxfnd_data_security_rules_fk1
        foreign key ( role_code )
            references xxcus.xxfnd_roles ( role_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"42edc468bce759ee4c63e1213ec08b7e18e5a179","type":"REF_CONSTRAINT","name":"XXFND_DATA_SECURITY_RULES_FK1","schemaName":"XXCUS","sxml":""}