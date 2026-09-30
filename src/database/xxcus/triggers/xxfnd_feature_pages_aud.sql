create or replace editionable trigger xxcus.xxfnd_feature_pages_aud after
    insert or update or delete on xxcus.xxfnd_feature_pages
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_FEATURE_PAGES',
                                   to_char(:new.app_alias)
                                   || '|'
                                   || to_char(:new.page_id),
                                   'I');

        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_FEATURE_PAGES',
                                   to_char(:old.app_alias)
                                   || '|'
                                   || to_char(:old.page_id),
                                   'D');

        return;
    end if;

    l_pk := to_char(:new.app_alias)
            || '|'
            || to_char(:new.page_id);

    if ( :old.app_alias <> :new.app_alias )
    or (
        :old.app_alias is null
        and :new.app_alias is not null
    )
    or (
        :old.app_alias is not null
        and :new.app_alias is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_FEATURE_PAGES',
                                   l_pk,
                                   'U',
                                   'APP_ALIAS',
                                   :old.app_alias,
                                   :new.app_alias);
    end if;

    if ( :old.page_id <> :new.page_id )
    or (
        :old.page_id is null
        and :new.page_id is not null
    )
    or (
        :old.page_id is not null
        and :new.page_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_FEATURE_PAGES',
                                   l_pk,
                                   'U',
                                   'PAGE_ID',
                                   to_char(:old.page_id,
                                           'TM9'),
                                   to_char(:new.page_id,
                                           'TM9'));
    end if;

    if ( :old.feature_code <> :new.feature_code )
    or (
        :old.feature_code is null
        and :new.feature_code is not null
    )
    or (
        :old.feature_code is not null
        and :new.feature_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_FEATURE_PAGES',
                                   l_pk,
                                   'U',
                                   'FEATURE_CODE',
                                   :old.feature_code,
                                   :new.feature_code);
    end if;

    if ( :old.tab_label <> :new.tab_label )
    or (
        :old.tab_label is null
        and :new.tab_label is not null
    )
    or (
        :old.tab_label is not null
        and :new.tab_label is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_FEATURE_PAGES',
                                   l_pk,
                                   'U',
                                   'TAB_LABEL',
                                   :old.tab_label,
                                   :new.tab_label);
    end if;

    if ( :old.tab_sequence <> :new.tab_sequence )
    or (
        :old.tab_sequence is null
        and :new.tab_sequence is not null
    )
    or (
        :old.tab_sequence is not null
        and :new.tab_sequence is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_FEATURE_PAGES',
                                   l_pk,
                                   'U',
                                   'TAB_SEQUENCE',
                                   to_char(:old.tab_sequence,
                                           'TM9'),
                                   to_char(:new.tab_sequence,
                                           'TM9'));
    end if;

end;
/

alter trigger xxcus.xxfnd_feature_pages_aud enable;


-- sqlcl_snapshot {"hash":"4c63bed95bd1ad89fbedf468737a20780a683887","type":"TRIGGER","name":"XXFND_FEATURE_PAGES_AUD","schemaName":"XXCUS","sxml":""}