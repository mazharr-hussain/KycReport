
begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DOCUMENT_CATEGORIES_TL', q'~create table xxfnd_document_categories_tl (
    category_code          varchar2(30)   not null,
    language_code          varchar2(10)   not null,
    category_name          varchar2(240)  not null,
    description            varchar2(500),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_categories_tl_pk primary key (category_code, language_code),
    constraint xxfnd_doc_categories_tl_fk1 foreign key (category_code)
        references xxfnd_document_categories (category_code) on delete cascade
)~');
end;
/
