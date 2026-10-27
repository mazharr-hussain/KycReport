
create or replace package xxfnd_attach_pkg authid definer as

    -- Release 86: where a new file of this entity and category goes - the storage of the entity's application
    -- (STORAGE_APPLICATION) for the category (XXFND_APP_STORAGE_V), as one row with the effective values:
    -- STORAGE_CONFIG_ID = the category's row, else the application's; SERVER_CODE, SHAREPOINT_SITE_ID / _DRIVE_ID,
    -- BUCKET_NAME, UCM_*, FOLDER_PATH_TEMPLATE effective; STORAGE_TYPE DATABASE when nothing applies or the setup is
    -- incomplete (an upload never fails because of the storage setup).
    function resolve_storage(p_entity_name in varchar2, p_category_code in varchar2)
        return xxfnd_storage_config%rowtype;

    ---------------------------------------------------------------- release 86 (part B): storage per application
    -- The application whose storage a document of this entity and category uses: the entity's application, else the
    -- category's, else COMMON.
    function storage_application(p_entity_name in varchar2, p_category_code in varchar2) return varchar2;
    -- The Storage editor (page 137), one application (COMMON = the instance). The application default: P_SERVER_CODE
    -- empty = the database; fields the server type does not use are cleared. ORA-20333 for an application that is
    -- not registered, ORA-20334 for a server that is not a storage server.
    procedure save_app_storage(p_application_code in varchar2,
                               p_server_code      in varchar2,
                               p_site             in varchar2 default null,
                               p_library          in varchar2 default null,
                               p_bucket           in varchar2 default null,
                               p_security_group   in varchar2 default null,
                               p_account          in varchar2 default null,
                               p_document_type    in varchar2 default null,
                               p_folder           in varchar2 default null);
    -- A category of that application: empty fields = the application's; P_SERVER_CODE empty = the application's
    -- server, DATABASE = this category in the database. All empty = no override (the row stays, emptied, for the
    -- documents stored by it). ORA-20335 for a category the application does not use.
    procedure save_category_storage(p_application_code in varchar2,
                                    p_category_code    in varchar2,
                                    p_server_code      in varchar2,
                                    p_site             in varchar2 default null,
                                    p_library          in varchar2 default null,
                                    p_bucket           in varchar2 default null,
                                    p_security_group   in varchar2 default null,
                                    p_account          in varchar2 default null,
                                    p_document_type    in varchar2 default null,
                                    p_folder           in varchar2 default null);
    -- OCI Object Storage: the URL of a bucket (P_OBJECT_NAME empty) or of an object on a server
    -- (<server URL>/n/<namespace>/b/<bucket>/o/<object name, URL-encoded>).
    function object_storage_url(p_server_code in varchar2, p_bucket in varchar2,
                                p_object_name in varchar2 default null) return varchar2;
    -- The object name of a new file: <folder>/<unique prefix>_<file name> (a new version never overwrites one).
    function object_name(p_folder in varchar2, p_file_name in varchar2) return varchar2;

    -- Y/N: may the current page region insert/update/delete attachments of this entity?
    -- P_ACTION = INSERT | UPDATE | DELETE. Used in button server-side conditions.
    function block_permission(p_app_alias        in varchar2,
                              p_page_id          in number,
                              p_region_static_id in varchar2,
                              p_entity_name      in varchar2,
                              p_action           in varchar2) return varchar2;

    -- Y/N: may this page offer this category (no usage rows = all categories).
    function category_allowed(p_app_alias in varchar2, p_page_id in number,
                              p_category_code in varchar2) return varchar2;

    -- Upload a file from APEX_APPLICATION_TEMP_FILES (File Browse item value).
    -- Returns ATTACHED_DOCUMENT_ID.
    function add_file(p_entity_name    in varchar2,
                      p_pk1_value      in varchar2,
                      p_category_code  in varchar2,
                      p_temp_file_name in varchar2,
                      p_title          in varchar2 default null,
                      p_description    in varchar2 default null,
                      p_document_date  in date     default null,
                      p_expiry_date    in date     default null,
                      p_pk2_value      in varchar2 default null,
                      p_pk3_value      in varchar2 default null,
                      p_pk4_value      in varchar2 default null,
                      p_pk5_value      in varchar2 default null,
                      p_page_id        in number   default null) return number;

    -- Short/long text (DATATYPE SHORT_TEXT or LONG_TEXT) or web page link (WEB_PAGE).
    function add_text(p_entity_name   in varchar2,
                      p_pk1_value     in varchar2,
                      p_category_code in varchar2,
                      p_datatype_code in varchar2,
                      p_title         in varchar2,
                      p_text          in clob     default null,
                      p_url           in varchar2 default null,
                      p_description   in varchar2 default null,
                      p_pk2_value     in varchar2 default null,
                      p_pk3_value     in varchar2 default null,
                      p_pk4_value     in varchar2 default null,
                      p_pk5_value     in varchar2 default null) return number;

    -- Replace the file with a new version; the attachment then points at it.
    -- Earlier versions stay in XXFND_DOCUMENTS and in the external store.
    procedure add_version(p_attached_document_id in number,
                          p_temp_file_name       in varchar2,
                          p_document_date        in date default null,
                          p_expiry_date          in date default null,
                          p_page_id              in number   default null);

    -- Upload limits: the category's value, else the attachment page's (P_PAGE_ID = the page that shows the
    -- attachments), else the application setting. Types: lower-case extensions, comma-separated; * = any.
    function max_file_size_mb(p_page_id in number, p_category_code in varchar2) return number;
    function allowed_file_types(p_page_id in number, p_category_code in varchar2) return varchar2;
    -- "PDF, JPG, PNG up to 10 MB" for the upload item's help text.
    function upload_rules_text(p_page_id in number, p_category_code in varchar2) return varchar2;

    -- Release 81: the display name of a registered document entity (page 131), in English.
    procedure save_entity_display_name(p_entity_name in varchar2, p_display_name in varchar2);

    procedure update_details(p_attached_document_id in number,
                             p_title                in varchar2,
                             p_description          in varchar2,
                             p_document_date        in date,
                             p_expiry_date          in date,
                             p_seq_num              in number default null);

    -- Soft delete (EBS: EXPIRATION_DATE). The row and the stored file remain.
    procedure remove(p_attached_document_id in number);

    -- Streams the file to the browser (APEX_HTTP.DOWNLOAD). Call from an
    -- Ajax/before-header process; it stops the APEX engine when done.
    procedure download(p_document_id in number, p_inline in varchar2 default 'N');

    -- Release 85 (the COMMON Attachments dialog, page 47, for any application's record): Y when the signed-in user may
    -- see the record - its row in the entity's table (XXFND_DOCUMENT_ENTITIES) is visible under the user's data
    -- security; N otherwise, or when the entity is not registered.
    function record_visible(p_entity_name in varchar2, p_pk1_value in varchar2) return varchar2;
    -- DOWNLOAD after that check on the document's record (ORA-20331 when the user may not see it).
    procedure download_checked(p_document_id in number, p_inline in varchar2 default 'N');
    -- The change of a document from the dialog (P_ACTION INSERT, UPDATE or DELETE) is allowed: the calling page's
    -- attachment registration permits it (BLOCK_PERMISSION) and the user may see the record; ORA-20332 otherwise.
    -- For UPDATE / DELETE, P_ATTACHED_DOCUMENT_ID must belong to that record.
    procedure assert_change(p_app_alias in varchar2, p_page_id in number, p_region_static_id in varchar2,
                            p_entity_name in varchar2, p_pk1_value in varchar2, p_action in varchar2,
                            p_attached_document_id in number default null);

    -- Copy all current attachments from one record to another (EBS COPY_ATTACHMENTS),
    -- e.g. from an intake request to the party. Shares the stored file.
    procedure copy_attachments(p_from_entity in varchar2, p_from_pk1 in varchar2,
                               p_to_entity   in varchar2, p_to_pk1   in varchar2,
                               p_category_code in varchar2 default null);

    ----------------------------------------------------------------------------
    -- Release 86 (part A): registration by an application and moving documents between records
    ----------------------------------------------------------------------------
    -- Each registration adds what is missing only (an administrator's change is kept; a re-run does nothing). The
    -- application must be registered (ORA-20180); a row of another application is refused (ORA-20186). COMMON's
    -- rows are the instance's (no application). Names: English, P_..._AR Arabic (as COMMON's seeds).
    procedure register_entity(p_application_code in varchar2,
                              p_entity_name      in varchar2,
                              p_table_name       in varchar2,
                              p_pk1_column       in varchar2,
                              p_display_name     in varchar2,
                              p_display_name_ar  in varchar2 default null,
                              p_pk2_column       in varchar2 default null);
    procedure register_category(p_application_code      in varchar2,
                                p_category_code         in varchar2,
                                p_category_name         in varchar2,
                                p_category_name_ar      in varchar2 default null,
                                p_description           in varchar2 default null,
                                p_default_datatype_code in varchar2 default 'FILE',
                                p_has_expiry_flag       in varchar2 default 'N',
                                p_max_age_days          in number   default null,
                                p_max_file_size_mb      in number   default null,
                                p_allowed_file_types    in varchar2 default null);
    -- An attachment page of the application (function = page of its APEX alias), one of its regions (block) and the
    -- entity that region attaches to, with what the user may do there. Call once per region and entity.
    -- ORA-20187 when the entity is not registered; ORA-20191 when the page is registered under another function.
    procedure register_attachment_page(p_application_code    in varchar2,
                                       p_function_code       in varchar2,
                                       p_function_name       in varchar2,
                                       p_page_id             in number,
                                       p_block_code          in varchar2,
                                       p_region_static_id    in varchar2,
                                       p_entity_name         in varchar2,
                                       p_pk1_page_item       in varchar2,
                                       p_block_name          in varchar2 default null,
                                       p_insert_allowed_flag in varchar2 default 'Y',
                                       p_update_allowed_flag in varchar2 default 'Y',
                                       p_delete_allowed_flag in varchar2 default 'N',
                                       p_display_sequence    in number   default 10);
    -- Moves every document of one record (removed ones too, each with all its versions) to another record of the
    -- same entity, after the documents that record already has. Nothing when there is nothing to move. The stored
    -- files stay where they are. (COPY_ATTACHMENTS shares documents instead.)
    procedure move_documents(p_entity_name in varchar2, p_from_pk1 in varchar2, p_to_pk1 in varchar2);

    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    procedure unregister_entity(p_application_code in varchar2, p_entity_name in varchar2);
    procedure unregister_category(p_application_code in varchar2, p_category_code in varchar2);
    -- C8: an attachment page (function) with its blocks
    procedure unregister_attachment_page(p_application_code in varchar2, p_function_code in varchar2);
    -- the application's attachment pages, categories, entities and storage settings
    procedure unregister_application(p_application_code in varchar2);
end xxfnd_attach_pkg;
/
