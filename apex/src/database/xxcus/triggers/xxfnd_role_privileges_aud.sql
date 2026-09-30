create or replace editionable trigger xxcus.xxfnd_role_privileges_aud after
    insert or update or delete on xxcus.xxfnd_role_privileges
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_ROLE_PRIVILEGES',
                                   to_char(:new.role_code)
                                   || '|'
                                   || to_char(:new.privilege_code),
                                   'I');

        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_ROLE_PRIVILEGES',
                                   to_char(:old.role_code)
                                   || '|'
                                   || to_char(:old.privilege_code),
                                   'D');

        return;
    end if;

    l_pk := to_char(:new.role_code)
            || '|'
            || to_char(:new.privilege_code);

    if ( :old.role_code <> :new.role_code )
    or (
        :old.role_code is null
        and :new.role_code is not null
    )
    or (
        :old.role_code is not null
        and :new.role_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ROLE_PRIVILEGES',
                                   l_pk,
                                   'U',
                                   'ROLE_CODE',
                                   :old.role_code,
                                   :new.role_code);
    end if;

    if ( :old.privilege_code <> :new.privilege_code )
    or (
        :old.privilege_code is null
        and :new.privilege_code is not null
    )
    or (
        :old.privilege_code is not null
        and :new.privilege_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ROLE_PRIVILEGES',
                                   l_pk,
                                   'U',
                                   'PRIVILEGE_CODE',
                                   :old.privilege_code,
                                   :new.privilege_code);
    end if;

end;
/

alter trigger xxcus.xxfnd_role_privileges_aud enable;


-- sqlcl_snapshot {"hash":"59c8ef72de918c3d50cff1f1c577d2b10f73cdaf","type":"TRIGGER","name":"XXFND_ROLE_PRIVILEGES_AUD","schemaName":"XXCUS","sxml":""}