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
comment on column xxfnd_attachment_functions.max_file_size_mb is 'Largest file accepted on this page (MB) unless the category says otherwise; overrides the application default.';
comment on column xxfnd_attachment_functions.allowed_file_types is 'File extensions accepted on this page unless the category says otherwise; overrides the application default.';

--------------------------------------------------------------------------------
-- Release 86 (part B): document storage per application, with category overrides, on the workspace servers.
--   Three levels: the server (XXFND_SERVERS, shared: OCI Object Storage, SharePoint, UCM) -> the application (one
--   XXFND_STORAGE_CONFIG row with CATEGORY_CODE empty; APPLICATION_CODE empty = COMMON, the instance): server, site +
--   document library (SharePoint), bucket (Object Storage), security group + account + document type (UCM), folder ->
--   a category of that application (a row with CATEGORY_CODE; every field may override the application's, the server
--   too; STORAGE_TYPE DATABASE = this category in the database). Effective value per field: category, else
--   application, else (folder only) /#CATEGORY#/#ENTITY_NAME#/#PK1_VALUE#; the DATABASE when no server applies or the
--   setup is incomplete (XXFND_APP_STORAGE_V.STATE) - an upload never fails because of the storage setup.
--   The old entity / endpoint columns stay (no data deleted) but are no longer read; 29 converts the old rules.
--   Each document keeps where it was stored (XXFND_DOCUMENTS.SERVER_CODE, STORAGE_CONTAINER = library or bucket).
--   Checked steps here (not in 29) because this package and its view use them and run before 29.
--------------------------------------------------------------------------------
begin
    -- the application column comes with 16i on older databases; a fresh install needs it here, before the view
    xxfnd_ddl_pkg.add_column('XXFND_STORAGE_CONFIG', 'APPLICATION_CODE', 'varchar2(30)');
    xxfnd_ddl_pkg.add_column('XXFND_STORAGE_CONFIG', 'SERVER_CODE', 'varchar2(255)');
    xxfnd_ddl_pkg.add_column('XXFND_STORAGE_CONFIG', 'BUCKET_NAME', 'varchar2(255)');
    xxfnd_ddl_pkg.set_nullable('XXFND_STORAGE_CONFIG', 'STORAGE_TYPE');
    xxfnd_ddl_pkg.set_nullable('XXFND_STORAGE_CONFIG', 'ENDPOINT_CODE');
    xxfnd_ddl_pkg.set_nullable('XXFND_STORAGE_CONFIG', 'FOLDER_PATH_TEMPLATE');
    xxfnd_ddl_pkg.drop_constraint('XXFND_STORAGE_CONFIG', 'XXFND_STORAGE_CONFIG_CK1');
    xxfnd_ddl_pkg.drop_constraint('XXFND_STORAGE_CONFIG', 'XXFND_STORAGE_CONFIG_CK2');
    xxfnd_ddl_pkg.add_constraint('XXFND_STORAGE_CONFIG', 'XXFND_STORAGE_CONFIG_CK4',
        q'~check (storage_type is null or storage_type in ('UCM','SHAREPOINT','OBJECT_STORAGE','DATABASE'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_STORAGE_CONFIG', 'XXFND_STORAGE_CONFIG_FK4',
        'foreign key (server_code) references xxfnd_servers (server_code)');
    xxfnd_ddl_pkg.ensure_index('XXFND_STORAGE_CONFIG_N1',
        'create index xxfnd_storage_config_n1 on xxfnd_storage_config (server_code)');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_STORAGE_CONFIG');   -- audit the new columns too
    -- a document keeps the place it was stored, whatever the setup becomes later
    xxfnd_ddl_pkg.add_column('XXFND_DOCUMENTS', 'SERVER_CODE', 'varchar2(255)');
    xxfnd_ddl_pkg.add_column('XXFND_DOCUMENTS', 'STORAGE_CONTAINER', 'varchar2(500)');
end;
/
comment on column xxfnd_storage_config.server_code is 'Release 86: the workspace server (XXFND_SERVERS). Application row: empty = the database. Category row: empty = the application''s server.';
comment on column xxfnd_storage_config.storage_type is 'Release 86: the server''s type (UCM, SHAREPOINT, OBJECT_STORAGE), DATABASE (no server; on a category row: this category in the database), empty on a category row = as the application.';
comment on column xxfnd_storage_config.category_code is 'Release 86: empty = the application default row; a category = that category''s overrides (empty fields = the application''s).';
comment on column xxfnd_storage_config.sharepoint_site_id is 'Release 86: SharePoint site (Microsoft Graph site ID).';
comment on column xxfnd_storage_config.sharepoint_drive_id is 'Release 86: SharePoint document library (Microsoft Graph drive ID).';
comment on column xxfnd_storage_config.bucket_name is 'Release 86: OCI Object Storage bucket.';
comment on column xxfnd_storage_config.folder_path_template is 'Folder for new files. Tokens: #CATEGORY# (= #CATEGORY_CODE#), #ENTITY_NAME#, #PK1_VALUE#..#PK5_VALUE#, #YYYY#. Empty: the application''s, else /#CATEGORY#/#ENTITY_NAME#/#PK1_VALUE#.';
comment on column xxfnd_storage_config.entity_name is 'Before release 86: the entity of the rule. No longer read (storage is per application and category).';
comment on column xxfnd_storage_config.endpoint_code is 'Before release 86: the retired integration endpoint. No longer read (SERVER_CODE).';
comment on column xxfnd_documents.server_code is 'Release 86: the server (XXFND_SERVERS) the file was stored on; empty for the database.';
comment on column xxfnd_documents.storage_container is 'Release 86: the SharePoint document library (drive ID) or the Object Storage bucket the file was stored in.';

-- a stored file may also be in OCI Object Storage (the same check as 13a, plus OBJECT_STORAGE)
declare
    l_cond varchar2(4000);
begin
    select max(search_condition_vc) into l_cond from user_constraints
     where table_name = 'XXFND_DOCUMENTS' and constraint_name = 'XXFND_DOCUMENTS_CK4';
    if l_cond is not null and instr(l_cond, 'OBJECT_STORAGE') = 0 then
        xxfnd_ddl_pkg.drop_constraint('XXFND_DOCUMENTS', 'XXFND_DOCUMENTS_CK4');
        xxfnd_ddl_pkg.add_constraint('XXFND_DOCUMENTS', 'XXFND_DOCUMENTS_CK4', q'[check (
            (datatype_code = 'FILE'     and storage_type in ('UCM','SHAREPOINT','DATABASE','OBJECT_STORAGE') and file_name is not null) or
            (datatype_code = 'WEB_PAGE' and url is not null and storage_type is null) or
            (datatype_code in ('SHORT_TEXT','LONG_TEXT') and storage_type is null))]');
    end if;
end;
/
