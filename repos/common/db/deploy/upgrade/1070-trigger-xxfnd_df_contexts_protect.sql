
-- Protected (seeded) contexts cannot be disabled or deleted from the screens.
create or replace trigger xxfnd_df_contexts_protect
    before update of enabled_flag or delete on xxfnd_df_contexts
    for each row
begin
    if :old.protected_flag = 'Y' and xxfnd_util_pkg.in_apex_session
       and (deleting or :new.enabled_flag = 'N') then
        raise_application_error(-20214, 'Context ' || :old.context_code || ' is system-defined and cannot be disabled or deleted.');
    end if;
end;
/
