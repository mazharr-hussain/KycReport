comment on table xxcus.xxfnd_employees is
    'One row per person. FUSION rows are maintained by the Fusion HCM sync and are read-only in the application; LOCAL rows are maintained by an administrator.'
    ;

comment on column xxcus.xxfnd_employees.user_name is
    'Matches APP_USER after sign-in (upper case). This is how a session resolves to a person.';


-- sqlcl_snapshot {"hash":"ddd796ca848ae7bea94ecfd4f409eca8845fd1d6","type":"COMMENT","name":"xxfnd_employees","schemaName":"xxcus","sxml":""}