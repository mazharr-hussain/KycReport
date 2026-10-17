
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
--------------------------------------------------------------------------------
-- 07_xxfnd_attach_pkg.sql
-- Attachments runtime (0.1), EBS model: a document (XXFND_DOCUMENTS) is linked
-- to any registered entity row (XXFND_ATTACHED_DOCUMENTS, ENTITY_NAME + PK1-5).
-- Files live in OCI Object Storage, Oracle UCM, SharePoint or the database; XXFND_STORAGE_CONFIG (release 86: per
-- application and category, XXFND_APP_STORAGE_V) decides where.
-- This package owns the attachment rules: categories, expiry and recency, versions, permissions per page
-- region, soft delete - and (release 81) the store transport, merged from XXFND_ATTACH_STORE_PKG.
--------------------------------------------------------------------------------
-- Upload limits (R15): per document category and per attachment page; the application default is in the
-- application settings ATTACH_MAX_FILE_SIZE_MB and ATTACH_ALLOWED_FILE_TYPES.
begin
    for t in (select column_value table_name from table(apex_t_varchar2('XXFND_DOCUMENT_CATEGORIES', 'XXFND_ATTACHMENT_FUNCTIONS'))) loop
        xxfnd_ddl_pkg.add_column(t.table_name, 'MAX_FILE_SIZE_MB',   'number');
        xxfnd_ddl_pkg.add_column(t.table_name, 'ALLOWED_FILE_TYPES', 'varchar2(500)');
        xxfnd_audit_pkg.create_audit_trigger(t.table_name);   -- audit the new columns too
    end loop;
end;
/
comment on column xxfnd_document_categories.max_file_size_mb is 'Largest file accepted for this category (MB); overrides the page and the application default.';
comment on column xxfnd_document_categories.allowed_file_types is 'File extensions accepted for this category, comma-separated (e.g. pdf,jpg); * = any; overrides the page and the application default.';
