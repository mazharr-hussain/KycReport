alter table xxcus.xxfnd_role_privileges
    add constraint xxfnd_role_privileges_fk1
        foreign key ( role_code )
            references xxcus.xxfnd_roles ( role_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"1cfe122baf7c2ed3b7774321065f1e8877647707","type":"REF_CONSTRAINT","name":"XXFND_ROLE_PRIVILEGES_FK1","schemaName":"XXCUS","sxml":""}