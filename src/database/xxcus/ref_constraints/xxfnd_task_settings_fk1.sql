alter table xxcus.xxfnd_task_settings
    add constraint xxfnd_task_settings_fk1
        foreign key ( escalation_role_code )
            references xxcus.xxfnd_roles ( role_code )
        enable;


-- sqlcl_snapshot {"hash":"3a38f00c6ca88ca9f6ac0fd6ca14156874cedd77","type":"REF_CONSTRAINT","name":"XXFND_TASK_SETTINGS_FK1","schemaName":"XXCUS","sxml":""}