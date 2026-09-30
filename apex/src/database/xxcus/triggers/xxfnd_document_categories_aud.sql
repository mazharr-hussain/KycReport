create or replace editionable trigger xxcus.xxfnd_document_categories_aud after
    insert or update or delete on xxcus.xxfnd_document_categories
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   to_char(:new.category_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   to_char(:old.category_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.category_code);
    if ( :old.category_code <> :new.category_code )
    or (
        :old.category_code is null
        and :new.category_code is not null
    )
    or (
        :old.category_code is not null
        and :new.category_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'CATEGORY_CODE',
                                   :old.category_code,
                                   :new.category_code);
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
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'APPLICATION_CODE',
                                   :old.application_code,
                                   :new.application_code);
    end if;

    if ( :old.category_name <> :new.category_name )
    or (
        :old.category_name is null
        and :new.category_name is not null
    )
    or (
        :old.category_name is not null
        and :new.category_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'CATEGORY_NAME',
                                   :old.category_name,
                                   :new.category_name);
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
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'DESCRIPTION',
                                   :old.description,
                                   :new.description);
    end if;

    if ( :old.default_datatype_code <> :new.default_datatype_code )
    or (
        :old.default_datatype_code is null
        and :new.default_datatype_code is not null
    )
    or (
        :old.default_datatype_code is not null
        and :new.default_datatype_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'DEFAULT_DATATYPE_CODE',
                                   :old.default_datatype_code,
                                   :new.default_datatype_code);
    end if;

    if ( :old.has_expiry_flag <> :new.has_expiry_flag )
    or (
        :old.has_expiry_flag is null
        and :new.has_expiry_flag is not null
    )
    or (
        :old.has_expiry_flag is not null
        and :new.has_expiry_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'HAS_EXPIRY_FLAG',
                                   :old.has_expiry_flag,
                                   :new.has_expiry_flag);
    end if;

    if ( :old.max_age_days <> :new.max_age_days )
    or (
        :old.max_age_days is null
        and :new.max_age_days is not null
    )
    or (
        :old.max_age_days is not null
        and :new.max_age_days is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'MAX_AGE_DAYS',
                                   to_char(:old.max_age_days,
                                           'TM9'),
                                   to_char(:new.max_age_days,
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
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
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
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
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
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'END_DATE_ACTIVE',
                                   to_char(:old.end_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                   to_char(:new.end_date_active,
                                           'YYYY-MM-DD HH24:MI:SS'));
    end if;

    if ( :old.max_file_size_mb <> :new.max_file_size_mb )
    or (
        :old.max_file_size_mb is null
        and :new.max_file_size_mb is not null
    )
    or (
        :old.max_file_size_mb is not null
        and :new.max_file_size_mb is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'MAX_FILE_SIZE_MB',
                                   to_char(:old.max_file_size_mb,
                                           'TM9'),
                                   to_char(:new.max_file_size_mb,
                                           'TM9'));
    end if;

    if ( :old.allowed_file_types <> :new.allowed_file_types )
    or (
        :old.allowed_file_types is null
        and :new.allowed_file_types is not null
    )
    or (
        :old.allowed_file_types is not null
        and :new.allowed_file_types is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_CATEGORIES',
                                   l_pk,
                                   'U',
                                   'ALLOWED_FILE_TYPES',
                                   :old.allowed_file_types,
                                   :new.allowed_file_types);
    end if;

end;
/

alter trigger xxcus.xxfnd_document_categories_aud enable;


-- sqlcl_snapshot {"hash":"a1ad4cc14fa2b7f9e719a704c22d7755e47c791d","type":"TRIGGER","name":"XXFND_DOCUMENT_CATEGORIES_AUD","schemaName":"XXCUS","sxml":""}