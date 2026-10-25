
begin
    if xxfnd_ddl_pkg.create_table('XXFND_DOCUMENT_CATEGORIES', q'~create table xxfnd_document_categories (
    category_code          varchar2(30)   not null,
    application_code       varchar2(30),
    category_name          varchar2(240)  not null,
    description            varchar2(500),
    default_datatype_code  varchar2(30)   default 'FILE' not null,
    has_expiry_flag        varchar2(1)    default 'N' not null,
    max_age_days           number(5),
    enabled_flag           varchar2(1)    default 'Y' not null,
    start_date_active      date           default trunc(sysdate) not null,
    end_date_active        date,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_categories_pk primary key (category_code),
    constraint xxfnd_doc_categories_ck1 check (default_datatype_code in ('FILE','SHORT_TEXT','LONG_TEXT','WEB_PAGE')),
    constraint xxfnd_doc_categories_ck2 check (has_expiry_flag in ('Y','N')),
    constraint xxfnd_doc_categories_ck3 check (enabled_flag in ('Y','N')),
    constraint xxfnd_doc_categories_ck4 check (max_age_days is null or max_age_days > 0)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_document_categories.has_expiry_flag is 'Y = the document itself expires (passport, licence); an expiry date is required on upload.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_document_categories.max_age_days is 'How recent the document must be when submitted (e.g. utility bill within 90 days). Separate from expiry.'~');
    end if;
end;
/
