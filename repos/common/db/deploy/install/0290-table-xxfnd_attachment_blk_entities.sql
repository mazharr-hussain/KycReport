
begin
    if xxfnd_ddl_pkg.create_table('XXFND_ATTACHMENT_BLK_ENTITIES', q'~create table xxfnd_attachment_blk_entities (
    function_code          varchar2(60)   not null,
    block_code             varchar2(60)   not null,
    entity_name            varchar2(60)   not null,
    pk1_page_item          varchar2(255)  not null,
    pk2_page_item          varchar2(255),
    pk3_page_item          varchar2(255),
    pk4_page_item          varchar2(255),
    pk5_page_item          varchar2(255),
    insert_allowed_flag    varchar2(1)    default 'Y' not null,
    update_allowed_flag    varchar2(1)    default 'Y' not null,
    delete_allowed_flag    varchar2(1)    default 'N' not null,
    display_sequence       number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_att_blk_entities_pk primary key (function_code, block_code, entity_name),
    constraint xxfnd_att_blk_entities_fk1 foreign key (function_code, block_code)
        references xxfnd_attachment_blocks (function_code, block_code) on delete cascade,
    constraint xxfnd_att_blk_entities_fk2 foreign key (entity_name) references xxfnd_document_entities (entity_name),
    constraint xxfnd_att_blk_entities_ck1 check (insert_allowed_flag in ('Y','N')),
    constraint xxfnd_att_blk_entities_ck2 check (update_allowed_flag in ('Y','N')),
    constraint xxfnd_att_blk_entities_ck3 check (delete_allowed_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_attachment_blk_entities is 'Which entity a region attaches to, which page items supply PK1-PK5, and what the user may do (FND_ATTACHMENT_BLK_ENTITIES).'~');
    end if;
end;
/
