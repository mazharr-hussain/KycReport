alter table xxcus.xxfnd_user_roles
    add constraint xxfnd_user_roles_fk1
        foreign key ( employee_id )
            references xxcus.xxfnd_employees ( employee_id )
        enable;


-- sqlcl_snapshot {"hash":"88c6294d3a6c7d235574b822a8c8ea4fa2c242c4","type":"REF_CONSTRAINT","name":"XXFND_USER_ROLES_FK1","schemaName":"XXCUS","sxml":""}