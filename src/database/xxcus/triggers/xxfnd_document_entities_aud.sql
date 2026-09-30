create or replace editionable trigger xxcus.xxfnd_document_entities_aud after
    insert or update or delete on xxcus.xxfnd_document_entities
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   to_char(:new.entity_name),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   to_char(:old.entity_name),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.entity_name);
    if ( :old.entity_name <> :new.entity_name )
    or (
        :old.entity_name is null
        and :new.entity_name is not null
    )
    or (
        :old.entity_name is not null
        and :new.entity_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   l_pk,
                                   'U',
                                   'ENTITY_NAME',
                                   :old.entity_name,
                                   :new.entity_name);
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
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
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
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   l_pk,
                                   'U',
                                   'TABLE_NAME',
                                   :old.table_name,
                                   :new.table_name);
    end if;

    if ( :old.pk1_column <> :new.pk1_column )
    or (
        :old.pk1_column is null
        and :new.pk1_column is not null
    )
    or (
        :old.pk1_column is not null
        and :new.pk1_column is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK1_COLUMN',
                                   :old.pk1_column,
                                   :new.pk1_column);
    end if;

    if ( :old.pk2_column <> :new.pk2_column )
    or (
        :old.pk2_column is null
        and :new.pk2_column is not null
    )
    or (
        :old.pk2_column is not null
        and :new.pk2_column is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK2_COLUMN',
                                   :old.pk2_column,
                                   :new.pk2_column);
    end if;

    if ( :old.pk3_column <> :new.pk3_column )
    or (
        :old.pk3_column is null
        and :new.pk3_column is not null
    )
    or (
        :old.pk3_column is not null
        and :new.pk3_column is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK3_COLUMN',
                                   :old.pk3_column,
                                   :new.pk3_column);
    end if;

    if ( :old.pk4_column <> :new.pk4_column )
    or (
        :old.pk4_column is null
        and :new.pk4_column is not null
    )
    or (
        :old.pk4_column is not null
        and :new.pk4_column is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK4_COLUMN',
                                   :old.pk4_column,
                                   :new.pk4_column);
    end if;

    if ( :old.pk5_column <> :new.pk5_column )
    or (
        :old.pk5_column is null
        and :new.pk5_column is not null
    )
    or (
        :old.pk5_column is not null
        and :new.pk5_column is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK5_COLUMN',
                                   :old.pk5_column,
                                   :new.pk5_column);
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
        xxfnd_audit_pkg.log_change('XXFND_DOCUMENT_ENTITIES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxfnd_document_entities_aud enable;


-- sqlcl_snapshot {"hash":"64a4b73aeb36c32deeceb4f00e020f4b9b6d7b20","type":"TRIGGER","name":"XXFND_DOCUMENT_ENTITIES_AUD","schemaName":"XXCUS","sxml":""}