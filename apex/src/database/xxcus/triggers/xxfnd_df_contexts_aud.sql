create or replace editionable trigger xxcus.xxfnd_df_contexts_aud after
    insert or update or delete on xxcus.xxfnd_df_contexts
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
                                   to_char(:new.descriptive_flexfield_code)
                                   || '|'
                                   || to_char(:new.context_code),
                                   'I');

        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
                                   to_char(:old.descriptive_flexfield_code)
                                   || '|'
                                   || to_char(:old.context_code),
                                   'D');

        return;
    end if;

    l_pk := to_char(:new.descriptive_flexfield_code)
            || '|'
            || to_char(:new.context_code);

    if ( :old.descriptive_flexfield_code <> :new.descriptive_flexfield_code )
    or (
        :old.descriptive_flexfield_code is null
        and :new.descriptive_flexfield_code is not null
    )
    or (
        :old.descriptive_flexfield_code is not null
        and :new.descriptive_flexfield_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
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
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
                                   l_pk,
                                   'U',
                                   'CONTEXT_CODE',
                                   :old.context_code,
                                   :new.context_code);
    end if;

    if ( :old.context_name <> :new.context_name )
    or (
        :old.context_name is null
        and :new.context_name is not null
    )
    or (
        :old.context_name is not null
        and :new.context_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
                                   l_pk,
                                   'U',
                                   'CONTEXT_NAME',
                                   :old.context_name,
                                   :new.context_name);
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
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

    if ( :old.global_flag <> :new.global_flag )
    or (
        :old.global_flag is null
        and :new.global_flag is not null
    )
    or (
        :old.global_flag is not null
        and :new.global_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
                                   l_pk,
                                   'U',
                                   'GLOBAL_FLAG',
                                   :old.global_flag,
                                   :new.global_flag);
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
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

    if ( :old.protected_flag <> :new.protected_flag )
    or (
        :old.protected_flag is null
        and :new.protected_flag is not null
    )
    or (
        :old.protected_flag is not null
        and :new.protected_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DF_CONTEXTS',
                                   l_pk,
                                   'U',
                                   'PROTECTED_FLAG',
                                   :old.protected_flag,
                                   :new.protected_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_df_contexts_aud enable;


-- sqlcl_snapshot {"hash":"9e287c3f3cd2120fc89f8c4ff7f5f09c8814442c","type":"TRIGGER","name":"XXFND_DF_CONTEXTS_AUD","schemaName":"XXCUS","sxml":""}