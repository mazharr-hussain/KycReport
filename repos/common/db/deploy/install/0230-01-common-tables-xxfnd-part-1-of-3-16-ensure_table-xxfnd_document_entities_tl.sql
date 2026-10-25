
begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DOCUMENT_ENTITIES_TL', q'~create table xxfnd_document_entities_tl (
    entity_name            varchar2(60)   not null,
    language_code          varchar2(10)   not null,
    user_entity_name       varchar2(240)  not null,
    description            varchar2(500),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_entities_tl_pk primary key (entity_name, language_code),
    constraint xxfnd_doc_entities_tl_fk1 foreign key (entity_name)
        references xxfnd_document_entities (entity_name) on delete cascade
)~');
end;
/
