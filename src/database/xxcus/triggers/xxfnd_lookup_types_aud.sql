create or replace editionable trigger xxcus.xxfnd_lookup_types_aud after
    insert or update or delete on xxcus.xxfnd_lookup_types
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_TYPES',
                                   to_char(:new.lookup_type),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_TYPES',
                                   to_char(:old.lookup_type),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.lookup_type);
    if ( :old.lookup_type <> :new.lookup_type )
    or (
        :old.lookup_type is null
        and :new.lookup_type is not null
    )
    or (
        :old.lookup_type is not null
        and :new.lookup_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_TYPES',
                                   l_pk,
                                   'U',
                                   'LOOKUP_TYPE',
                                   :old.lookup_type,
                                   :new.lookup_type);
    end if;

    if ( :old.meaning <> :new.meaning )
    or (
        :old.meaning is null
        and :new.meaning is not null
    )
    or (
        :old.meaning is not null
        and :new.meaning is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_TYPES',
                                   l_pk,
                                   'U',
                                   'MEANING',
                                   :old.meaning,
                                   :new.meaning);
    end if;

    if ( :old.description <> :new.description )
    or (
        :old.description is null
        and :new.description is not null
    )
    or (
        :old.description is not null
        and :new.description is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_TYPES',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

    if ( :old.application_code <> :new.application_code )
    or (
        :old.application_code is null
        and :new.application_code is not null
    )
    or (
        :old.application_code is not null
        and :new.application_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_TYPES',
                                   l_pk,
                                   'U',
                                   'APPLICATION_CODE',
                                   :old.application_code,
                                   :new.application_code);
    end if;

    if ( :old.customization_level <> :new.customization_level )
    or (
        :old.customization_level is null
        and :new.customization_level is not null
    )
    or (
        :old.customization_level is not null
        and :new.customization_level is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_TYPES',
                                   l_pk,
                                   'U',
                                   'CUSTOMIZATION_LEVEL',
                                   :old.customization_level,
                                   :new.customization_level);
    end if;

end;
/

alter trigger xxcus.xxfnd_lookup_types_aud enable;


-- sqlcl_snapshot {"hash":"2651daa4e304c7e1ac120165f95d0d05d6f99c1e","type":"TRIGGER","name":"XXFND_LOOKUP_TYPES_AUD","schemaName":"XXCUS","sxml":""}