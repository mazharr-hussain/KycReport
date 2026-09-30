create or replace editionable trigger xxcus.xxfnd_df_segments_aud after
    insert or update or delete on xxcus.xxfnd_df_segments
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   to_char(:new.descriptive_flexfield_code)
                                   || '|'
                                   || to_char(:new.context_code)
                                   || '|'
                                   || to_char(:new.segment_code),
                                   'I');

        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   to_char(:old.descriptive_flexfield_code)
                                   || '|'
                                   || to_char(:old.context_code)
                                   || '|'
                                   || to_char(:old.segment_code),
                                   'D');

        return;
    end if;

    l_pk := to_char(:new.descriptive_flexfield_code)
            || '|'
            || to_char(:new.context_code)
            || '|'
            || to_char(:new.segment_code);

    if ( :old.descriptive_flexfield_code <> :new.descriptive_flexfield_code )
    or (
        :old.descriptive_flexfield_code is null
        and :new.descriptive_flexfield_code is not null
    )
    or (
        :old.descriptive_flexfield_code is not null
        and :new.descriptive_flexfield_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'DESCRIPTIVE_FLEXFIELD_CODE',
                                   :old.descriptive_flexfield_code,
                                   :new.descriptive_flexfield_code);
    end if;

    if ( :old.context_code <> :new.context_code )
    or (
        :old.context_code is null
        and :new.context_code is not null
    )
    or (
        :old.context_code is not null
        and :new.context_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'CONTEXT_CODE',
                                   :old.context_code,
                                   :new.context_code);
    end if;

    if ( :old.segment_code <> :new.segment_code )
    or (
        :old.segment_code is null
        and :new.segment_code is not null
    )
    or (
        :old.segment_code is not null
        and :new.segment_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'SEGMENT_CODE',
                                   :old.segment_code,
                                   :new.segment_code);
    end if;

    if ( :old.column_name <> :new.column_name )
    or (
        :old.column_name is null
        and :new.column_name is not null
    )
    or (
        :old.column_name is not null
        and :new.column_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'COLUMN_NAME',
                                   :old.column_name,
                                   :new.column_name);
    end if;

    if ( :old.sequence_number <> :new.sequence_number )
    or (
        :old.sequence_number is null
        and :new.sequence_number is not null
    )
    or (
        :old.sequence_number is not null
        and :new.sequence_number is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'SEQUENCE_NUMBER',
                                   to_char(:old.sequence_number,
                                           'TM9'),
                                   to_char(:new.sequence_number,
                                           'TM9'));
    end if;

    if ( :old.prompt <> :new.prompt )
    or (
        :old.prompt is null
        and :new.prompt is not null
    )
    or (
        :old.prompt is not null
        and :new.prompt is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'PROMPT',
                                   :old.prompt,
                                   :new.prompt);
    end if;

    if ( :old.help_text <> :new.help_text )
    or (
        :old.help_text is null
        and :new.help_text is not null
    )
    or (
        :old.help_text is not null
        and :new.help_text is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'HELP_TEXT',
                                   :old.help_text,
                                   :new.help_text);
    end if;

    if ( :old.value_set_code <> :new.value_set_code )
    or (
        :old.value_set_code is null
        and :new.value_set_code is not null
    )
    or (
        :old.value_set_code is not null
        and :new.value_set_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'VALUE_SET_CODE',
                                   :old.value_set_code,
                                   :new.value_set_code);
    end if;

    if ( :old.required_flag <> :new.required_flag )
    or (
        :old.required_flag is null
        and :new.required_flag is not null
    )
    or (
        :old.required_flag is not null
        and :new.required_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'REQUIRED_FLAG',
                                   :old.required_flag,
                                   :new.required_flag);
    end if;

    if ( :old.default_type <> :new.default_type )
    or (
        :old.default_type is null
        and :new.default_type is not null
    )
    or (
        :old.default_type is not null
        and :new.default_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'DEFAULT_TYPE',
                                   :old.default_type,
                                   :new.default_type);
    end if;

    if ( :old.default_value <> :new.default_value )
    or (
        :old.default_value is null
        and :new.default_value is not null
    )
    or (
        :old.default_value is not null
        and :new.default_value is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'DEFAULT_VALUE',
                                   :old.default_value,
                                   :new.default_value);
    end if;

    if ( :old.read_only_flag <> :new.read_only_flag )
    or (
        :old.read_only_flag is null
        and :new.read_only_flag is not null
    )
    or (
        :old.read_only_flag is not null
        and :new.read_only_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'READ_ONLY_FLAG',
                                   :old.read_only_flag,
                                   :new.read_only_flag);
    end if;

    if ( :old.display_flag <> :new.display_flag )
    or (
        :old.display_flag is null
        and :new.display_flag is not null
    )
    or (
        :old.display_flag is not null
        and :new.display_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'DISPLAY_FLAG',
                                   :old.display_flag,
                                   :new.display_flag);
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
        xxfnd_audit_pkg.log_change('XXFND_DF_SEGMENTS',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_df_segments_aud enable;


-- sqlcl_snapshot {"hash":"9360712bf280e4095503a25d7753d78ba3dca03c","type":"TRIGGER","name":"XXFND_DF_SEGMENTS_AUD","schemaName":"XXCUS","sxml":""}