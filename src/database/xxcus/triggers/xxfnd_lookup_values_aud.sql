create or replace editionable trigger xxcus.xxfnd_lookup_values_aud after
    insert or update or delete on xxcus.xxfnd_lookup_values
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   to_char(:new.lookup_type)
                                   || '|'
                                   || to_char(:new.lookup_code),
                                   'I');

        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   to_char(:old.lookup_type)
                                   || '|'
                                   || to_char(:old.lookup_code),
                                   'D');

        return;
    end if;

    l_pk := to_char(:new.lookup_type)
            || '|'
            || to_char(:new.lookup_code);

    if ( :old.lookup_type <> :new.lookup_type )
    or (
        :old.lookup_type is null
        and :new.lookup_type is not null
    )
    or (
        :old.lookup_type is not null
        and :new.lookup_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'LOOKUP_TYPE',
                                   :old.lookup_type,
                                   :new.lookup_type);
    end if;

    if ( :old.lookup_code <> :new.lookup_code )
    or (
        :old.lookup_code is null
        and :new.lookup_code is not null
    )
    or (
        :old.lookup_code is not null
        and :new.lookup_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'LOOKUP_CODE',
                                   :old.lookup_code,
                                   :new.lookup_code);
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
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
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
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

    if ( :old.tag <> :new.tag )
    or (
        :old.tag is null
        and :new.tag is not null
    )
    or (
        :old.tag is not null
        and :new.tag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'TAG',
                                   :old.tag,
                                   :new.tag);
    end if;

    if ( :old.parent_lookup_type <> :new.parent_lookup_type )
    or (
        :old.parent_lookup_type is null
        and :new.parent_lookup_type is not null
    )
    or (
        :old.parent_lookup_type is not null
        and :new.parent_lookup_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'PARENT_LOOKUP_TYPE',
                                   :old.parent_lookup_type,
                                   :new.parent_lookup_type);
    end if;

    if ( :old.parent_lookup_code <> :new.parent_lookup_code )
    or (
        :old.parent_lookup_code is null
        and :new.parent_lookup_code is not null
    )
    or (
        :old.parent_lookup_code is not null
        and :new.parent_lookup_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'PARENT_LOOKUP_CODE',
                                   :old.parent_lookup_code,
                                   :new.parent_lookup_code);
    end if;

    if ( :old.display_sequence <> :new.display_sequence )
    or (
        :old.display_sequence is null
        and :new.display_sequence is not null
    )
    or (
        :old.display_sequence is not null
        and :new.display_sequence is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'DISPLAY_SEQUENCE',
                                   to_char(:old.display_sequence,
                                           'TM9'),
                                   to_char(:new.display_sequence,
                                           'TM9'));
    end if;

    if ( :old.enabled_flag <> :new.enabled_flag )
    or (
        :old.enabled_flag is null
        and :new.enabled_flag is not null
    )
    or (
        :old.enabled_flag is not null
        and :new.enabled_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

    if ( :old.start_date_active <> :new.start_date_active )
    or (
        :old.start_date_active is null
        and :new.start_date_active is not null
    )
    or (
        :old.start_date_active is not null
        and :new.start_date_active is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'START_DATE_ACTIVE',
                                   to_char(:old.start_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                   to_char(:new.start_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'));
    end if;

    if ( :old.end_date_active <> :new.end_date_active )
    or (
        :old.end_date_active is null
        and :new.end_date_active is not null
    )
    or (
        :old.end_date_active is not null
        and :new.end_date_active is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_LOOKUP_VALUES',
                                   l_pk,
                                   'U',
                                   'END_DATE_ACTIVE',
                                   to_char(:old.end_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                   to_char(:new.end_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'));
    end if;

end;
/

alter trigger xxcus.xxfnd_lookup_values_aud enable;


-- sqlcl_snapshot {"hash":"155c28162ae1fd3adbb50e28951ab5adf768cd24","type":"TRIGGER","name":"XXFND_LOOKUP_VALUES_AUD","schemaName":"XXCUS","sxml":""}