alter table xxcus.xxfnd_role_privileges
    add constraint xxfnd_role_privileges_fk2
        foreign key ( privilege_code )
            references xxcus.xxfnd_privileges ( privilege_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"f953a985d65df4080236fa60d73950ef3dd08064","type":"REF_CONSTRAINT","name":"XXFND_ROLE_PRIVILEGES_FK2","schemaName":"XXCUS","sxml":""}