
--==============================================================================
-- 0.1  ATTACHMENTS  (EBS: FND_DOCUMENT_ENTITIES, FND_ATTACHMENT_FUNCTIONS,
--      FND_ATTACHMENT_BLOCKS, FND_ATTACHMENT_BLK_ENTITIES, FND_DOC_CATEGORY_USAGES,
--      FND_DOCUMENT_CATEGORIES, FND_DOCUMENTS, FND_ATTACHED_DOCUMENTS)
--==============================================================================
begin
    if xxfnd_ddl_pkg.create_table('XXFND_DOCUMENT_ENTITIES', q'~create table xxfnd_document_entities (
    entity_name            varchar2(60)   not null,
    application_code       varchar2(30),
    table_name             varchar2(128)  not null,
    pk1_column             varchar2(128)  not null,
    pk2_column             varchar2(128),
    pk3_column             varchar2(128),
    pk4_column             varchar2(128),
    pk5_column             varchar2(128),
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_entities_pk primary key (entity_name),
    constraint xxfnd_doc_entities_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_document_entities is 'Registered attachable entities (FND_DOCUMENT_ENTITIES). Gives ATTACHED_DOCUMENTS.ENTITY_NAME a real foreign key.'~');
    end if;
end;
/
