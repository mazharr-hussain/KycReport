create or replace package xxcus.xxfnd_attach_pkg authid definer as

    -- Most specific enabled storage row: entity+category, entity, category, default.
    function resolve_storage (
        p_entity_name   in varchar2,
        p_category_code in varchar2
    ) return xxfnd_storage_config%rowtype;

    -- Y/N: may the current page region insert/update/delete attachments of this entity?
    -- P_ACTION = INSERT | UPDATE | DELETE. Used in button server-side conditions.
    function block_permission (
        p_app_alias        in varchar2,
        p_page_id          in number,
        p_region_static_id in varchar2,
        p_entity_name      in varchar2,
        p_action           in varchar2
    ) return varchar2;

    -- Y/N: may this page offer this category (no usage rows = all categories).
    function category_allowed (
        p_app_alias     in varchar2,
        p_page_id       in number,
        p_category_code in varchar2
    ) return varchar2;

    -- Upload a file from APEX_APPLICATION_TEMP_FILES (File Browse item value).
    -- Returns ATTACHED_DOCUMENT_ID.
    function add_file (
        p_entity_name    in varchar2,
        p_pk1_value      in varchar2,
        p_category_code  in varchar2,
        p_temp_file_name in varchar2,
        p_title          in varchar2 default null,
        p_description    in varchar2 default null,
        p_document_date  in date default null,
        p_expiry_date    in date default null,
        p_pk2_value      in varchar2 default null,
        p_pk3_value      in varchar2 default null,
        p_pk4_value      in varchar2 default null,
        p_pk5_value      in varchar2 default null,
        p_page_id        in number default null
    ) return number;

    -- Short/long text (DATATYPE SHORT_TEXT or LONG_TEXT) or web page link (WEB_PAGE).
    function add_text (
        p_entity_name   in varchar2,
        p_pk1_value     in varchar2,
        p_category_code in varchar2,
        p_datatype_code in varchar2,
        p_title         in varchar2,
        p_text          in clob default null,
        p_url           in varchar2 default null,
        p_description   in varchar2 default null,
        p_pk2_value     in varchar2 default null,
        p_pk3_value     in varchar2 default null,
        p_pk4_value     in varchar2 default null,
        p_pk5_value     in varchar2 default null
    ) return number;

    -- Replace the file with a new version; the attachment then points at it.
    -- Earlier versions stay in XXFND_DOCUMENTS and in the external store.
    procedure add_version (
        p_attached_document_id in number,
        p_temp_file_name       in varchar2,
        p_document_date        in date default null,
        p_expiry_date          in date default null,
        p_page_id              in number default null
    );

    -- Upload limits: the category's value, else the attachment page's (P_PAGE_ID = the page that shows the
    -- attachments), else the application setting. Types: lower-case extensions, comma-separated; * = any.
    function max_file_size_mb (
        p_page_id       in number,
        p_category_code in varchar2
    ) return number;

    function allowed_file_types (
        p_page_id       in number,
        p_category_code in varchar2
    ) return varchar2;
    -- "PDF, JPG, PNG up to 10 MB" for the upload item's help text.
    function upload_rules_text (
        p_page_id       in number,
        p_category_code in varchar2
    ) return varchar2;

    procedure update_details (
        p_attached_document_id in number,
        p_title                in varchar2,
        p_description          in varchar2,
        p_document_date        in date,
        p_expiry_date          in date,
        p_seq_num              in number default null
    );

    -- Soft delete (EBS: EXPIRATION_DATE). The row and the stored file remain.
    procedure remove (
        p_attached_document_id in number
    );

    -- Streams the file to the browser (APEX_HTTP.DOWNLOAD). Call from an
    -- Ajax/before-header process; it stops the APEX engine when done.
    procedure download (
        p_document_id in number,
        p_inline      in varchar2 default 'N'
    );

    -- Copy all current attachments from one record to another (EBS COPY_ATTACHMENTS),
    -- e.g. from an intake request to the party. Shares the stored file.
    procedure copy_attachments (
        p_from_entity   in varchar2,
        p_from_pk1      in varchar2,
        p_to_entity     in varchar2,
        p_to_pk1        in varchar2,
        p_category_code in varchar2 default null
    );

end xxfnd_attach_pkg;
/


-- sqlcl_snapshot {"hash":"06409522f83556c10ef78992605fcc6bd938e2dd","type":"PACKAGE_SPEC","name":"XXFND_ATTACH_PKG","schemaName":"XXCUS","sxml":""}