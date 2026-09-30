create or replace editionable trigger xxcus.xxfnd_doc_category_usages_aud after
    insert or update or delete on xxcus.xxfnd_doc_category_usages
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_DOC_CATEGORY_USAGES',
                                   to_char(:new.function_code)
                                   || '|'
                                   || to_char(:new.category_code),
                                   'I');

        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_DOC_CATEGORY_USAGES',
                                   to_char(:old.function_code)
                                   || '|'
                                   || to_char(:old.category_code),
                                   'D');

        return;
    end if;

    l_pk := to_char(:new.function_code)
            || '|'
            || to_char(:new.category_code);

    if ( :old.function_code <> :new.function_code )
    or (
        :old.function_code is null
        and :new.function_code is not null
    )
    or (
        :old.function_code is not null
        and :new.function_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOC_CATEGORY_USAGES',
                                   l_pk,
                                   'U',
                                   'FUNCTION_CODE',
                                   :old.function_code,
                                   :new.function_code);
    end if;

    if ( :old.category_code <> :new.category_code )
    or (
        :old.category_code is null
        and :new.category_code is not null
    )
    or (
        :old.category_code is not null
        and :new.category_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOC_CATEGORY_USAGES',
                                   l_pk,
                                   'U',
                                   'CATEGORY_CODE',
                                   :old.category_code,
                                   :new.category_code);
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
        xxfnd_audit_pkg.log_change('XXFND_DOC_CATEGORY_USAGES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_doc_category_usages_aud enable;


-- sqlcl_snapshot {"hash":"39d83bd8a98d3f1375ba1cf27e217d7074b9a311","type":"TRIGGER","name":"XXFND_DOC_CATEGORY_USAGES_AUD","schemaName":"XXCUS","sxml":""}