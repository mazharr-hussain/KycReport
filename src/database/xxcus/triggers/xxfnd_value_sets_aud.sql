create or replace editionable trigger xxcus.xxfnd_value_sets_aud after
    insert or update or delete on xxcus.xxfnd_value_sets
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   to_char(:new.value_set_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   to_char(:old.value_set_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.value_set_code);
    if ( :old.value_set_code <> :new.value_set_code )
    or (
        :old.value_set_code is null
        and :new.value_set_code is not null
    )
    or (
        :old.value_set_code is not null
        and :new.value_set_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'VALUE_SET_CODE',
                                   :old.value_set_code,
                                   :new.value_set_code);
    end if;

    if ( :old.value_set_name <> :new.value_set_name )
    or (
        :old.value_set_name is null
        and :new.value_set_name is not null
    )
    or (
        :old.value_set_name is not null
        and :new.value_set_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'VALUE_SET_NAME',
                                   :old.value_set_name,
                                   :new.value_set_name);
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
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

    if ( :old.validation_type <> :new.validation_type )
    or (
        :old.validation_type is null
        and :new.validation_type is not null
    )
    or (
        :old.validation_type is not null
        and :new.validation_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'VALIDATION_TYPE',
                                   :old.validation_type,
                                   :new.validation_type);
    end if;

    if ( :old.format_type <> :new.format_type )
    or (
        :old.format_type is null
        and :new.format_type is not null
    )
    or (
        :old.format_type is not null
        and :new.format_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'FORMAT_TYPE',
                                   :old.format_type,
                                   :new.format_type);
    end if;

    if ( :old.maximum_size <> :new.maximum_size )
    or (
        :old.maximum_size is null
        and :new.maximum_size is not null
    )
    or (
        :old.maximum_size is not null
        and :new.maximum_size is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'MAXIMUM_SIZE',
                                   to_char(:old.maximum_size,
                                           'TM9'),
                                   to_char(:new.maximum_size,
                                           'TM9'));
    end if;

    if ( :old.number_precision <> :new.number_precision )
    or (
        :old.number_precision is null
        and :new.number_precision is not null
    )
    or (
        :old.number_precision is not null
        and :new.number_precision is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'NUMBER_PRECISION',
                                   to_char(:old.number_precision,
                                           'TM9'),
                                   to_char(:new.number_precision,
                                           'TM9'));
    end if;

    if ( :old.minimum_value <> :new.minimum_value )
    or (
        :old.minimum_value is null
        and :new.minimum_value is not null
    )
    or (
        :old.minimum_value is not null
        and :new.minimum_value is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'MINIMUM_VALUE',
                                   :old.minimum_value,
                                   :new.minimum_value);
    end if;

    if ( :old.maximum_value <> :new.maximum_value )
    or (
        :old.maximum_value is null
        and :new.maximum_value is not null
    )
    or (
        :old.maximum_value is not null
        and :new.maximum_value is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'MAXIMUM_VALUE',
                                   :old.maximum_value,
                                   :new.maximum_value);
    end if;

    if ( :old.uppercase_only_flag <> :new.uppercase_only_flag )
    or (
        :old.uppercase_only_flag is null
        and :new.uppercase_only_flag is not null
    )
    or (
        :old.uppercase_only_flag is not null
        and :new.uppercase_only_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'UPPERCASE_ONLY_FLAG',
                                   :old.uppercase_only_flag,
                                   :new.uppercase_only_flag);
    end if;

    if ( :old.lookup_type <> :new.lookup_type )
    or (
        :old.lookup_type is null
        and :new.lookup_type is not null
    )
    or (
        :old.lookup_type is not null
        and :new.lookup_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'LOOKUP_TYPE',
                                   :old.lookup_type,
                                   :new.lookup_type);
    end if;

    if ( :old.parent_value_set_code <> :new.parent_value_set_code )
    or (
        :old.parent_value_set_code is null
        and :new.parent_value_set_code is not null
    )
    or (
        :old.parent_value_set_code is not null
        and :new.parent_value_set_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_VALUE_SETS',
                                   l_pk,
                                   'U',
                                   'PARENT_VALUE_SET_CODE',
                                   :old.parent_value_set_code,
                                   :new.parent_value_set_code);
    end if;

end;
/

alter trigger xxcus.xxfnd_value_sets_aud enable;


-- sqlcl_snapshot {"hash":"72e3376fab47147ded0cc2b2269735a4a038925e","type":"TRIGGER","name":"XXFND_VALUE_SETS_AUD","schemaName":"XXCUS","sxml":""}