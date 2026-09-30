alter table xxcus.xxfnd_user_roles
    add constraint xxfnd_user_roles_fk2
        foreign key ( role_code )
            references xxcus.xxfnd_roles ( role_code )
        enable;


-- sqlcl_snapshot {"hash":"295263e73868ffc8c7b98e46720634c523980e52","type":"REF_CONSTRAINT","name":"XXFND_USER_ROLES_FK2","schemaName":"XXCUS","sxml":""}