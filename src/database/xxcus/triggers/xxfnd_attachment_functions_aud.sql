create or replace editionable trigger xxcus.xxfnd_attachment_functions_aud after
    insert or update or delete on xxcus.xxfnd_attachment_functions
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   to_char(:new.function_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   to_char(:old.function_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.function_code);
    if ( :old.function_code <> :new.function_code )
    or (
        :old.function_code is null
        and :new.function_code is not null
    )
    or (
        :old.function_code is not null
        and :new.function_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   l_pk,
                                   'U',
                                   'FUNCTION_CODE',
                                   :old.function_code,
                                   :new.function_code);
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
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   l_pk,
                                   'U',
                                   'APPLICATION_CODE',
                                   :old.application_code,
                                   :new.application_code);
    end if;

    if ( :old.function_name <> :new.function_name )
    or (
        :old.function_name is null
        and :new.function_name is not null
    )
    or (
        :old.function_name is not null
        and :new.function_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   l_pk,
                                   'U',
                                   'FUNCTION_NAME',
                                   :old.function_name,
                                   :new.function_name);
    end if;

    if ( :old.apex_app_alias <> :new.apex_app_alias )
    or (
        :old.apex_app_alias is null
        and :new.apex_app_alias is not null
    )
    or (
        :old.apex_app_alias is not null
        and :new.apex_app_alias is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   l_pk,
                                   'U',
                                   'APEX_APP_ALIAS',
                                   :old.apex_app_alias,
                                   :new.apex_app_alias);
    end if;

    if ( :old.apex_page_id <> :new.apex_page_id )
    or (
        :old.apex_page_id is null
        and :new.apex_page_id is not null
    )
    or (
        :old.apex_page_id is not null
        and :new.apex_page_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   l_pk,
                                   'U',
                                   'APEX_PAGE_ID',
                                   to_char(:old.apex_page_id,
                                           'TM9'),
                                   to_char(:new.apex_page_id,
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
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
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
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
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
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_FUNCTIONS',
                                   l_pk,
                                   'U',
                                   'ALLOWED_FILE_TYPES',
                                   :old.allowed_file_types,
                                   :new.allowed_file_types);
    end if;

end;
/

alter trigger xxcus.xxfnd_attachment_functions_aud enable;


-- sqlcl_snapshot {"hash":"9141a5a6def76975d356ff64bf84d2a11c2e7318","type":"TRIGGER","name":"XXFND_ATTACHMENT_FUNCTIONS_AUD","schemaName":"XXCUS","sxml":""}