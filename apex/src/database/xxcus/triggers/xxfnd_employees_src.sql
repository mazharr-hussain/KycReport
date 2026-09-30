create or replace editionable trigger xxcus.xxfnd_employees_src before
    update or delete on xxcus.xxfnd_employees
    for each row
begin
    if
        xxfnd_util_pkg.in_apex_session
        and not xxfnd_security_pkg.sync_running
        and :old.source_type = 'FUSION'
    then
        if deleting
        or :new.user_name <> :old.user_name
        or :new.full_name <> :old.full_name
        or :new.email_address <> :old.email_address
        or :new.source_type <> :old.source_type
        or nvl(:new.fusion_person_id,
               -1) <> nvl(:old.fusion_person_id,
                          -1) then
            raise_application_error(-20132, 'This person comes from Oracle Fusion HCM; change them there.');
        end if;
    end if;

    if updating then
        :new.user_name := upper(:new.user_name);
    end if;

end;
/

alter trigger xxcus.xxfnd_employees_src enable;


-- sqlcl_snapshot {"hash":"fc17948c5371b34cc3332fce7f0b040975ba46a1","type":"TRIGGER","name":"XXFND_EMPLOYEES_SRC","schemaName":"XXCUS","sxml":""}