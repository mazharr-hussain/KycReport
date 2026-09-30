create or replace editionable trigger xxcus.xxfnd_attachment_blk_entities_aud after
    insert or update or delete on xxcus.xxfnd_attachment_blk_entities
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   to_char(:new.function_code)
                                   || '|'
                                   || to_char(:new.block_code)
                                   || '|'
                                   || to_char(:new.entity_name),
                                   'I');

        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   to_char(:old.function_code)
                                   || '|'
                                   || to_char(:old.block_code)
                                   || '|'
                                   || to_char(:old.entity_name),
                                   'D');

        return;
    end if;

    l_pk := to_char(:new.function_code)
            || '|'
            || to_char(:new.block_code)
            || '|'
            || to_char(:new.entity_name);

    if ( :old.function_code <> :new.function_code )
    or (
        :old.function_code is null
        and :new.function_code is not null
    )
    or (
        :old.function_code is not null
        and :new.function_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'FUNCTION_CODE',
                                   :old.function_code,
                                   :new.function_code);
    end if;

    if ( :old.block_code <> :new.block_code )
    or (
        :old.block_code is null
        and :new.block_code is not null
    )
    or (
        :old.block_code is not null
        and :new.block_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'BLOCK_CODE',
                                   :old.block_code,
                                   :new.block_code);
    end if;

    if ( :old.entity_name <> :new.entity_name )
    or (
        :old.entity_name is null
        and :new.entity_name is not null
    )
    or (
        :old.entity_name is not null
        and :new.entity_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'ENTITY_NAME',
                                   :old.entity_name,
                                   :new.entity_name);
    end if;

    if ( :old.pk1_page_item <> :new.pk1_page_item )
    or (
        :old.pk1_page_item is null
        and :new.pk1_page_item is not null
    )
    or (
        :old.pk1_page_item is not null
        and :new.pk1_page_item is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK1_PAGE_ITEM',
                                   :old.pk1_page_item,
                                   :new.pk1_page_item);
    end if;

    if ( :old.pk2_page_item <> :new.pk2_page_item )
    or (
        :old.pk2_page_item is null
        and :new.pk2_page_item is not null
    )
    or (
        :old.pk2_page_item is not null
        and :new.pk2_page_item is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK2_PAGE_ITEM',
                                   :old.pk2_page_item,
                                   :new.pk2_page_item);
    end if;

    if ( :old.pk3_page_item <> :new.pk3_page_item )
    or (
        :old.pk3_page_item is null
        and :new.pk3_page_item is not null
    )
    or (
        :old.pk3_page_item is not null
        and :new.pk3_page_item is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK3_PAGE_ITEM',
                                   :old.pk3_page_item,
                                   :new.pk3_page_item);
    end if;

    if ( :old.pk4_page_item <> :new.pk4_page_item )
    or (
        :old.pk4_page_item is null
        and :new.pk4_page_item is not null
    )
    or (
        :old.pk4_page_item is not null
        and :new.pk4_page_item is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK4_PAGE_ITEM',
                                   :old.pk4_page_item,
                                   :new.pk4_page_item);
    end if;

    if ( :old.pk5_page_item <> :new.pk5_page_item )
    or (
        :old.pk5_page_item is null
        and :new.pk5_page_item is not null
    )
    or (
        :old.pk5_page_item is not null
        and :new.pk5_page_item is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'PK5_PAGE_ITEM',
                                   :old.pk5_page_item,
                                   :new.pk5_page_item);
    end if;

    if ( :old.insert_allowed_flag <> :new.insert_allowed_flag )
    or (
        :old.insert_allowed_flag is null
        and :new.insert_allowed_flag is not null
    )
    or (
        :old.insert_allowed_flag is not null
        and :new.insert_allowed_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'INSERT_ALLOWED_FLAG',
                                   :old.insert_allowed_flag,
                                   :new.insert_allowed_flag);
    end if;

    if ( :old.update_allowed_flag <> :new.update_allowed_flag )
    or (
        :old.update_allowed_flag is null
        and :new.update_allowed_flag is not null
    )
    or (
        :old.update_allowed_flag is not null
        and :new.update_allowed_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'UPDATE_ALLOWED_FLAG',
                                   :old.update_allowed_flag,
                                   :new.update_allowed_flag);
    end if;

    if ( :old.delete_allowed_flag <> :new.delete_allowed_flag )
    or (
        :old.delete_allowed_flag is null
        and :new.delete_allowed_flag is not null
    )
    or (
        :old.delete_allowed_flag is not null
        and :new.delete_allowed_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'DELETE_ALLOWED_FLAG',
                                   :old.delete_allowed_flag,
                                   :new.delete_allowed_flag);
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
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLK_ENTITIES',
                                   l_pk,
                                   'U',
                                   'DISPLAY_SEQUENCE',
                                   to_char(:old.display_sequence,
                                           'TM9'),
                                   to_char(:new.display_sequence,
                                           'TM9'));
    end if;

end;
/

alter trigger xxcus.xxfnd_attachment_blk_entities_aud enable;


-- sqlcl_snapshot {"hash":"20614b9fda704ceadaba9b250ffd9da6808a8a06","type":"TRIGGER","name":"XXFND_ATTACHMENT_BLK_ENTITIES_AUD","schemaName":"XXCUS","sxml":""}