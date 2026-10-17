
-- Fusion-sourced people are owned by the HCM sync; only the sync (no APEX session) may change their identity fields.
-- (release 83: created here, after XXFND_INTEGRATION_PKG, instead of in 08)
create or replace trigger xxfnd_employees_src
    before update or delete on xxfnd_employees
    for each row
begin
    if xxfnd_util_pkg.in_apex_session and not xxfnd_integration_pkg.sync_running
       and :old.source_type = 'FUSION' then
        if deleting
           or :new.user_name     <> :old.user_name
           or :new.full_name     <> :old.full_name
           or :new.email_address <> :old.email_address
           or :new.source_type   <> :old.source_type
           or nvl(:new.fusion_person_id, -1) <> nvl(:old.fusion_person_id, -1) then
            raise_application_error(-20132, 'This person comes from Oracle Fusion HCM; change them there.');
        end if;
    end if;
    if updating then
        :new.user_name := upper(:new.user_name);
    end if;
end;
/
