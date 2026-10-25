
begin
    if xxfnd_ddl_pkg.create_table('XXFND_DOC_CATEGORY_USAGES', q'~create table xxfnd_doc_category_usages (
    function_code          varchar2(60)   not null,
    category_code          varchar2(30)   not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_category_usages_pk primary key (function_code, category_code),
    constraint xxfnd_doc_category_usages_fk1 foreign key (function_code)
        references xxfnd_attachment_functions (function_code) on delete cascade,
    constraint xxfnd_doc_category_usages_fk2 foreign key (category_code) references xxfnd_document_categories (category_code),
    constraint xxfnd_doc_category_usages_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_doc_category_usages is 'Categories a page may offer (FND_DOC_CATEGORY_USAGES). A page with no rows here offers every enabled category.'~');
    end if;
end;
/
