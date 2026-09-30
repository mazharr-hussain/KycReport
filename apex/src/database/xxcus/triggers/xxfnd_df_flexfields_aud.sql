create or replace editionable trigger xxcus.xxfnd_df_flexfields_aud after
    insert or update or delete on xxcus.xxfnd_df_flexfields
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   to_char(:new.descriptive_flexfield_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   to_char(:old.descriptive_flexfield_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.descriptive_flexfield_code);
    if ( :old.descriptive_flexfield_code <> :new.descriptive_flexfield_code )
    or (
        :old.descriptive_flexfield_code is null
        and :new.descriptive_flexfield_code is not null
    )
    or (
        :old.descriptive_flexfield_code is not null
        and :new.descriptive_flexfield_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'DESCRIPTIVE_FLEXFIELD_CODE',
                                   :old.descriptive_flexfield_code,
                                   :new.descriptive_flexfield_code);
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
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'APPLICATION_CODE',
                                   :old.application_code,
                                   :new.application_code);
    end if;

    if ( :old.table_name <> :new.table_name )
    or (
        :old.table_name is null
        and :new.table_name is not null
    )
    or (
        :old.table_name is not null
        and :new.table_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'TABLE_NAME',
                                   :old.table_name,
                                   :new.table_name);
    end if;

    if ( :old.pk_column_name <> :new.pk_column_name )
    or (
        :old.pk_column_name is null
        and :new.pk_column_name is not null
    )
    or (
        :old.pk_column_name is not null
        and :new.pk_column_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'PK_COLUMN_NAME',
                                   :old.pk_column_name,
                                   :new.pk_column_name);
    end if;

    if ( :old.context_column_name <> :new.context_column_name )
    or (
        :old.context_column_name is null
        and :new.context_column_name is not null
    )
    or (
        :old.context_column_name is not null
        and :new.context_column_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'CONTEXT_COLUMN_NAME',
                                   :old.context_column_name,
                                   :new.context_column_name);
    end if;

    if ( :old.context_reference_column <> :new.context_reference_column )
    or (
        :old.context_reference_column is null
        and :new.context_reference_column is not null
    )
    or (
        :old.context_reference_column is not null
        and :new.context_reference_column is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'CONTEXT_REFERENCE_COLUMN',
                                   :old.context_reference_column,
                                   :new.context_reference_column);
    end if;

    if ( :old.default_context_code <> :new.default_context_code )
    or (
        :old.default_context_code is null
        and :new.default_context_code is not null
    )
    or (
        :old.default_context_code is not null
        and :new.default_context_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'DEFAULT_CONTEXT_CODE',
                                   :old.default_context_code,
                                   :new.default_context_code);
    end if;

    if ( :old.context_required_flag <> :new.context_required_flag )
    or (
        :old.context_required_flag is null
        and :new.context_required_flag is not null
    )
    or (
        :old.context_required_flag is not null
        and :new.context_required_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'CONTEXT_REQUIRED_FLAG',
                                   :old.context_required_flag,
                                   :new.context_required_flag);
    end if;

    if ( :old.context_user_selectable_flag <> :new.context_user_selectable_flag )
    or (
        :old.context_user_selectable_flag is null
        and :new.context_user_selectable_flag is not null
    )
    or (
        :old.context_user_selectable_flag is not null
        and :new.context_user_selectable_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'CONTEXT_USER_SELECTABLE_FLAG',
                                   :old.context_user_selectable_flag,
                                   :new.context_user_selectable_flag);
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
        xxfnd_audit_pkg.log_change('XXFND_DF_FLEXFIELDS',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_df_flexfields_aud enable;


-- sqlcl_snapshot {"hash":"0807c7caf201c54647d7d993a2fc6b464d506d7d","type":"TRIGGER","name":"XXFND_DF_FLEXFIELDS_AUD","schemaName":"XXCUS","sxml":""}