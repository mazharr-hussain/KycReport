
begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DOCUMENTS_TL', q'~create table xxfnd_documents_tl (
    document_id            number         not null,
    language_code          varchar2(10)   not null,
    title                  varchar2(400),
    description            varchar2(2000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_documents_tl_pk primary key (document_id, language_code),
    constraint xxfnd_documents_tl_fk1 foreign key (document_id) references xxfnd_documents (document_id) on delete cascade
)~');
end;
/
