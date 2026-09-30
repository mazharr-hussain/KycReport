alter table xxcus.xxfnd_attachment_blk_entities
    add constraint xxfnd_att_blk_entities_fk1
        foreign key ( function_code,
                      block_code )
            references xxcus.xxfnd_attachment_blocks ( function_code,
                                                       block_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"824c42bafe99d34ecaf42e9c72e4ee8203817e0c","type":"REF_CONSTRAINT","name":"XXFND_ATT_BLK_ENTITIES_FK1","schemaName":"XXCUS","sxml":""}