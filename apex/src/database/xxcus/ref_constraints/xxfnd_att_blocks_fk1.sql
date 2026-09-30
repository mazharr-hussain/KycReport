alter table xxcus.xxfnd_attachment_blocks
    add constraint xxfnd_att_blocks_fk1
        foreign key ( function_code )
            references xxcus.xxfnd_attachment_functions ( function_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"109acf75b4a8ec99d7555ee9fa4727440e30ce5e","type":"REF_CONSTRAINT","name":"XXFND_ATT_BLOCKS_FK1","schemaName":"XXCUS","sxml":""}