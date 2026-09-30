create or replace editionable trigger xxcus.xxfnd_lookup_values_lvl before
    insert or update or delete on xxcus.xxfnd_lookup_values
    for each row
declare
    l_level xxfnd_lookup_types.customization_level%type;
begin
    if not xxfnd_util_pkg.in_apex_session then
        return;
    end if;
    select
        customization_level
    into l_level
    from
        xxfnd_lookup_types
    where
        lookup_type = coalesce(:new.lookup_type,
                               :old.lookup_type);

    if l_level = 'S' then
        raise_application_error(-20130, 'Values of this lookup type are defined by the system and cannot be changed.');
    elsif
        l_level = 'E'
        and ( deleting
        or (
            updating
            and ( :new.lookup_code <> :old.lookup_code )
        ) )
    then
        raise_application_error(-20131, 'Values of this lookup type can be added or disabled, but not deleted or recoded.');
    end if;

end;
/

alter trigger xxcus.xxfnd_lookup_values_lvl enable;


-- sqlcl_snapshot {"hash":"6f57368cbb9699ef5b49f29a88f292e1f6775517","type":"TRIGGER","name":"XXFND_LOOKUP_VALUES_LVL","schemaName":"XXCUS","sxml":""}