create or replace editionable trigger xxcus.xxfnd_attachment_blocks_aud after
    insert or update or delete on xxcus.xxfnd_attachment_blocks
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLOCKS',
                                   to_char(:new.function_code)
                                   || '|'
                                   || to_char(:new.block_code),
                                   'I');

        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLOCKS',
                                   to_char(:old.function_code)
                                   || '|'
                                   || to_char(:old.block_code),
                                   'D');

        return;
    end if;

    l_pk := to_char(:new.function_code)
            || '|'
            || to_char(:new.block_code);

    if ( :old.function_code <> :new.function_code )
    or (
        :old.function_code is null
        and :new.function_code is not null
    )
    or (
        :old.function_code is not null
        and :new.function_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLOCKS',
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
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLOCKS',
                                   l_pk,
                                   'U',
                                   'BLOCK_CODE',
                                   :old.block_code,
                                   :new.block_code);
    end if;

    if ( :old.region_static_id <> :new.region_static_id )
    or (
        :old.region_static_id is null
        and :new.region_static_id is not null
    )
    or (
        :old.region_static_id is not null
        and :new.region_static_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLOCKS',
                                   l_pk,
                                   'U',
                                   'REGION_STATIC_ID',
                                   :old.region_static_id,
                                   :new.region_static_id);
    end if;

    if ( :old.block_name <> :new.block_name )
    or (
        :old.block_name is null
        and :new.block_name is not null
    )
    or (
        :old.block_name is not null
        and :new.block_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLOCKS',
                                   l_pk,
                                   'U',
                                   'BLOCK_NAME',
                                   :old.block_name,
                                   :new.block_name);
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
        xxfnd_audit_pkg.log_change('XXFND_ATTACHMENT_BLOCKS',
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

alter trigger xxcus.xxfnd_attachment_blocks_aud enable;


-- sqlcl_snapshot {"hash":"c79c6de1d1c4118eb977e92b2c5704e63aff5721","type":"TRIGGER","name":"XXFND_ATTACHMENT_BLOCKS_AUD","schemaName":"XXCUS","sxml":""}