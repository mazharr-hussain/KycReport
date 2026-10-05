--------------------------------------------------------------------------------
-- 07_xxfnd_attach_pkg.sql
-- Attachments runtime (0.1), EBS model: a document (XXFND_DOCUMENTS) is linked
-- to any registered entity row (XXFND_ATTACHED_DOCUMENTS, ENTITY_NAME + PK1-5).
-- Files live in Oracle UCM or SharePoint; the database keeps the reference only.
-- XXFND_STORAGE_CONFIG decides where; XXFND_ATTACH_STORE_PKG (07a) talks to the
-- store. This package owns the attachment rules: categories, expiry and
-- recency, versions, permissions per page region, soft delete.
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

create or replace package xxfnd_attach_pkg authid definer as

    -- Most specific enabled storage row: entity+category, entity, category, default; DATABASE when none.
    function resolve_storage(p_entity_name in varchar2, p_category_code in varchar2)
        return xxfnd_storage_config%rowtype;

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

    -- Copy all current attachments from one record to another (EBS COPY_ATTACHMENTS),
    -- e.g. from an intake request to the party. Shares the stored file.
    procedure copy_attachments(p_from_entity in varchar2, p_from_pk1 in varchar2,
                               p_to_entity   in varchar2, p_to_pk1   in varchar2,
                               p_category_code in varchar2 default null);

end xxfnd_attach_pkg;
/

create or replace package body xxfnd_attach_pkg as

    -- application defaults when the ATTACH_* application settings are empty
    c_default_size_mb constant number        := 10;
    c_default_types   constant varchar2(200) := 'pdf,jpg,jpeg,png,tif,tiff,doc,docx,xls,xlsx,msg,eml';

    subtype t_stored is xxfnd_attach_store_pkg.t_stored;

    ----------------------------------------------------------------------------
    -- configuration lookups
    ----------------------------------------------------------------------------
    function resolve_storage(p_entity_name in varchar2, p_category_code in varchar2)
        return xxfnd_storage_config%rowtype is
        l_cfg xxfnd_storage_config%rowtype;
    begin
        select * into l_cfg
          from (select s.*
                  from xxfnd_storage_config s
                 where s.enabled_flag = 'Y'
                   and (s.entity_name   = p_entity_name   or s.entity_name   is null)
                   and (s.category_code = p_category_code or s.category_code is null)
                 order by case when s.entity_name   is not null then 0 else 1 end,
                          case when s.category_code is not null then 0 else 1 end,
                          s.priority)
         where rownum = 1;
        return l_cfg;
    exception
        when no_data_found then
            -- nothing configured: keep the file in the database
            return xxfnd_attach_store_pkg.database_config;
    end resolve_storage;

    function block_permission(p_app_alias        in varchar2,
                              p_page_id          in number,
                              p_region_static_id in varchar2,
                              p_entity_name      in varchar2,
                              p_action           in varchar2) return varchar2 is
        l_flag varchar2(1);
    begin
        select case upper(p_action)
                 when 'INSERT' then be.insert_allowed_flag
                 when 'UPDATE' then be.update_allowed_flag
                 when 'DELETE' then be.delete_allowed_flag
               end
          into l_flag
          from xxfnd_attachment_functions f
          join xxfnd_attachment_blocks b      on b.function_code = f.function_code
          join xxfnd_attachment_blk_entities be
            on be.function_code = b.function_code and be.block_code = b.block_code
         where upper(f.apex_app_alias) = upper(p_app_alias)
           and f.apex_page_id = p_page_id
           and f.enabled_flag = 'Y'
           and lower(b.region_static_id) = lower(p_region_static_id)
           and be.entity_name = p_entity_name;
        return nvl(l_flag, 'N');
    exception
        when no_data_found then
            return 'N';
    end block_permission;

    function category_allowed(p_app_alias in varchar2, p_page_id in number,
                              p_category_code in varchar2) return varchar2 is
        l_usages  pls_integer;
        l_allowed pls_integer;
    begin
        select count(*), count(case when u.category_code = p_category_code and u.enabled_flag = 'Y' then 1 end)
          into l_usages, l_allowed
          from xxfnd_attachment_functions f
          join xxfnd_doc_category_usages u on u.function_code = f.function_code
         where upper(f.apex_app_alias) = upper(p_app_alias)
           and f.apex_page_id = p_page_id;
        return case when l_usages = 0 or l_allowed > 0 then 'Y' else 'N' end;
    end category_allowed;

    ----------------------------------------------------------------------------
    -- helpers
    ----------------------------------------------------------------------------
    function folder_path(p_cfg in xxfnd_storage_config%rowtype, p_entity in varchar2,
                         p_pk1 in varchar2, p_pk2 in varchar2, p_pk3 in varchar2,
                         p_pk4 in varchar2, p_pk5 in varchar2, p_category in varchar2) return varchar2 is
        l_path varchar2(2000) := p_cfg.folder_path_template;
    begin
        l_path := replace(l_path, '#ENTITY_NAME#',   p_entity);
        l_path := replace(l_path, '#PK1_VALUE#',     p_pk1);
        l_path := replace(l_path, '#PK2_VALUE#',     p_pk2);
        l_path := replace(l_path, '#PK3_VALUE#',     p_pk3);
        l_path := replace(l_path, '#PK4_VALUE#',     p_pk4);
        l_path := replace(l_path, '#PK5_VALUE#',     p_pk5);
        l_path := replace(l_path, '#CATEGORY_CODE#', p_category);
        l_path := replace(l_path, '#YYYY#',          to_char(sysdate, 'YYYY'));
        l_path := regexp_replace(l_path, '/+', '/');
        return rtrim(ltrim(l_path, '/'), '/');
    end folder_path;

    procedure get_temp_file(p_name in varchar2, p_blob out blob, p_filename out varchar2, p_mime out varchar2) is
    begin
        select blob_content, filename, mime_type
          into p_blob, p_filename, p_mime
          from apex_application_temp_files
         where name = p_name;
    exception
        when no_data_found then
            raise_application_error(-20302, 'The uploaded file was not found. Select the file again.');
    end get_temp_file;

    procedure check_category_rules(p_category in varchar2, p_document_date in date, p_expiry_date in date) is
        l_cat xxfnd_document_categories%rowtype;
    begin
        select * into l_cat from xxfnd_document_categories where category_code = p_category;
        if l_cat.enabled_flag <> 'Y'
           or trunc(sysdate) not between l_cat.start_date_active and nvl(l_cat.end_date_active, trunc(sysdate)) then
            raise_application_error(-20303, 'Document category ' || p_category || ' is not active.');
        end if;
        if l_cat.has_expiry_flag = 'Y' and p_expiry_date is null then
            raise_application_error(-20304, 'Enter the expiry date for ' || l_cat.category_name || '.');
        end if;
        if p_expiry_date is not null and p_expiry_date < trunc(sysdate) then
            raise_application_error(-20305, 'This document has already expired.');
        end if;
        if l_cat.max_age_days is not null then
            if p_document_date is null then
                raise_application_error(-20306, 'Enter the issue date for ' || l_cat.category_name || '.');
            elsif p_document_date < trunc(sysdate) - l_cat.max_age_days then
                raise_application_error(-20307, l_cat.category_name || ' must be issued within the last '
                    || l_cat.max_age_days || ' days.');
            end if;
        end if;
    end check_category_rules;

    procedure check_entity(p_entity in varchar2) is
        l_count pls_integer;
    begin
        select count(*) into l_count from xxfnd_document_entities where entity_name = p_entity and enabled_flag = 'Y';
        if l_count = 0 then
            raise_application_error(-20308, 'Entity ' || p_entity || ' is not enabled for attachments.');
        end if;
    end check_entity;

    ----------------------------------------------------------------------------
    -- upload limits: category, else attachment page, else application setting
    ----------------------------------------------------------------------------

    -- ' .PDF, Jpg ' -> 'pdf,jpg'
    function normalise_types(p_types in varchar2) return varchar2 is
    begin
        return nullif(trim(both ',' from regexp_replace(lower(regexp_replace(p_types, '[[:space:].]', '')), ',+', ',')), '');
    end normalise_types;

    function app_setting(p_name in varchar2) return varchar2 is
    begin
        return apex_app_setting.get_value(p_name);
    exception
        when others then
            return null;   -- no APEX session (scripts, jobs outside APEX)
    end app_setting;

    procedure page_limits(p_page_id in number, p_size out number, p_types out varchar2) is
    begin
        select max(case when f.max_file_size_mb > 0 then f.max_file_size_mb end), max(f.allowed_file_types)
          into p_size, p_types
          from xxfnd_attachment_functions f
         where f.apex_app_alias = nvl(v('APP_ALIAS'), 'KYC')
           and f.apex_page_id   = p_page_id
           and f.enabled_flag   = 'Y';
    end page_limits;

    function max_file_size_mb(p_page_id in number, p_category_code in varchar2) return number is
        l_cat   number;
        l_page  number;
        l_types varchar2(500);
    begin
        select max(case when max_file_size_mb > 0 then max_file_size_mb end) into l_cat
          from xxfnd_document_categories where category_code = p_category_code;
        page_limits(p_page_id, l_page, l_types);
        return coalesce(l_cat, l_page,
                        to_number(app_setting('ATTACH_MAX_FILE_SIZE_MB') default null on conversion error),
                        c_default_size_mb);
    end max_file_size_mb;

    function allowed_file_types(p_page_id in number, p_category_code in varchar2) return varchar2 is
        l_cat   varchar2(500);
        l_size  number;
        l_page  varchar2(500);
    begin
        select max(allowed_file_types) into l_cat from xxfnd_document_categories where category_code = p_category_code;
        page_limits(p_page_id, l_size, l_page);
        return coalesce(normalise_types(l_cat), normalise_types(l_page),
                        normalise_types(app_setting('ATTACH_ALLOWED_FILE_TYPES')), c_default_types);
    end allowed_file_types;

    function upload_rules_text(p_page_id in number, p_category_code in varchar2) return varchar2 is
        l_types varchar2(500) := allowed_file_types(p_page_id, p_category_code);
    begin
        return case when l_types = '*' then 'Any file type' else upper(replace(l_types, ',', ', ')) end
               || ' up to ' || max_file_size_mb(p_page_id, p_category_code) || ' MB';
    end upload_rules_text;

    procedure check_upload(p_page_id in number, p_category in varchar2, p_filename in varchar2, p_blob in blob) is
        l_max   number        := max_file_size_mb(p_page_id, p_category);
        l_types varchar2(500) := allowed_file_types(p_page_id, p_category);
        l_ext   varchar2(100) := lower(regexp_substr(p_filename, '\.([^.]+)$', 1, 1, null, 1));
        l_bytes number        := dbms_lob.getlength(p_blob);
    begin
        if l_bytes > l_max * 1024 * 1024 then
            raise_application_error(-20321, 'The file is ' || round(l_bytes / 1024 / 1024, 1)
                || ' MB; the limit for this document is ' || l_max || ' MB.');
        end if;
        if l_types <> '*' and (l_ext is null
                               or instr(',' || l_types || ',', ',' || l_ext || ',') = 0) then
            raise_application_error(-20322, 'Files of type ' || nvl(upper(l_ext), '(none)')
                || ' are not accepted here. Accepted: ' || upper(replace(l_types, ',', ', ')) || '.');
        end if;
    end check_upload;

    ----------------------------------------------------------------------------
    -- store a file for a document row
    ----------------------------------------------------------------------------
    function store_file(p_cfg in xxfnd_storage_config%rowtype, p_entity in varchar2,
                        p_pk1 in varchar2, p_pk2 in varchar2, p_pk3 in varchar2, p_pk4 in varchar2, p_pk5 in varchar2,
                        p_category in varchar2, p_file in blob, p_filename in varchar2, p_mime in varchar2,
                        p_title in varchar2, p_previous_external_id in varchar2) return t_stored is
        l_folder varchar2(2000) := folder_path(p_cfg, p_entity, p_pk1, p_pk2, p_pk3, p_pk4, p_pk5, p_category);
        l_stored t_stored;
    begin
        l_stored := xxfnd_attach_store_pkg.upload(p_cfg, p_entity, p_pk1, l_folder, p_file, p_filename, p_mime,
                                                  p_title, p_previous_external_id);

        if p_cfg.storage_type = xxfnd_attach_store_pkg.c_database then
            return l_stored;    -- no external folder
        end if;
        -- Remember the record's folder so later files land in the same place.
        merge into xxfnd_entity_containers c
        using (select p_entity e, p_pk1 k, p_cfg.storage_config_id s from dual) x
           on (c.entity_name = x.e and c.pk1_value = x.k and c.storage_config_id = x.s)
         when not matched then
            insert (entity_name, pk1_value, storage_config_id, external_folder_path)
            values (x.e, x.k, x.s, nvl(l_folder, '/'));
        return l_stored;
    end store_file;

    procedure set_tl(p_document_id in number, p_title in varchar2, p_description in varchar2) is
    begin
        merge into xxfnd_documents_tl t
        using (select p_document_id d, xxfnd_util_pkg.current_lang l from dual) x
           on (t.document_id = x.d and t.language_code = x.l)
         when matched then update set t.title = p_title, t.description = p_description
         when not matched then insert (document_id, language_code, title, description)
                               values (x.d, x.l, p_title, p_description);
    end set_tl;

    function next_seq(p_entity in varchar2, p_pk1 in varchar2) return number is
        l_seq number;
    begin
        select nvl(max(seq_num), 0) + 10 into l_seq
          from xxfnd_attached_documents
         where entity_name = p_entity and pk1_value = p_pk1;
        return l_seq;
    end next_seq;

    ----------------------------------------------------------------------------
    -- public API
    ----------------------------------------------------------------------------
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
                      p_page_id        in number   default null) return number is
        l_cfg      xxfnd_storage_config%rowtype;
        l_blob     blob;
        l_filename varchar2(400);
        l_mime     varchar2(255);
        l_stored   t_stored;
        l_doc_id   number;
        l_att_id   number;
        l_seq      number;
    begin
        check_entity(p_entity_name);
        check_category_rules(p_category_code, p_document_date, p_expiry_date);
        get_temp_file(p_temp_file_name, l_blob, l_filename, l_mime);
        check_upload(p_page_id, p_category_code, l_filename, l_blob);
        l_cfg := resolve_storage(p_entity_name, p_category_code);

        l_stored := store_file(l_cfg, p_entity_name, p_pk1_value, p_pk2_value, p_pk3_value, p_pk4_value,
                               p_pk5_value, p_category_code, l_blob, l_filename, l_mime,
                               nvl(p_title, l_filename), null);

        insert into xxfnd_documents (category_code, datatype_code, version_number, storage_config_id,
                                     storage_type, external_document_id, external_version_id, external_url,
                                     file_name, mime_type, file_size_bytes, document_date, expiry_date,
                                     upload_status)
        values (p_category_code, 'FILE', 1, l_cfg.storage_config_id, l_cfg.storage_type,
                l_stored.external_document_id, l_stored.external_version_id, l_stored.external_url,
                l_filename, l_mime, dbms_lob.getlength(l_blob), p_document_date, p_expiry_date, 'STORED')
        returning document_id into l_doc_id;
        set_tl(l_doc_id, nvl(p_title, l_filename), p_description);

        -- NEXT_SEQ is private to the package body, so it cannot be called inside SQL (PLS-00231).
        l_seq := next_seq(p_entity_name, p_pk1_value);
        insert into xxfnd_attached_documents (document_id, entity_name, pk1_value, pk2_value, pk3_value,
                                              pk4_value, pk5_value, category_code, seq_num)
        values (l_doc_id, p_entity_name, p_pk1_value, p_pk2_value, p_pk3_value, p_pk4_value, p_pk5_value,
                p_category_code, l_seq)
        returning attached_document_id into l_att_id;
        return l_att_id;
    end add_file;

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
                      p_pk5_value     in varchar2 default null) return number is
        l_doc_id number;
        l_att_id number;
        l_seq    number;
    begin
        check_entity(p_entity_name);
        check_category_rules(p_category_code, null, null);
        if p_datatype_code not in ('SHORT_TEXT','LONG_TEXT','WEB_PAGE') then
            raise_application_error(-20312, 'Use ADD_FILE for files.');
        end if;
        if p_datatype_code = 'WEB_PAGE' and not regexp_like(p_url, '^https?://', 'i') then
            raise_application_error(-20313, 'Enter a web address starting with http:// or https://.');
        end if;
        if p_datatype_code = 'SHORT_TEXT' and dbms_lob.getlength(p_text) > 4000 then
            raise_application_error(-20314, 'Short text is limited to 4000 characters; use long text.');
        end if;

        insert into xxfnd_documents (category_code, datatype_code, version_number, text_content, url, upload_status)
        values (p_category_code, p_datatype_code, 1,
                case when p_datatype_code <> 'WEB_PAGE' then p_text end,
                case when p_datatype_code =  'WEB_PAGE' then p_url end,
                'NOT_APPLICABLE')
        returning document_id into l_doc_id;
        set_tl(l_doc_id, p_title, p_description);

        -- NEXT_SEQ is private to the package body, so it cannot be called inside SQL (PLS-00231).
        l_seq := next_seq(p_entity_name, p_pk1_value);
        insert into xxfnd_attached_documents (document_id, entity_name, pk1_value, pk2_value, pk3_value,
                                              pk4_value, pk5_value, category_code, seq_num)
        values (l_doc_id, p_entity_name, p_pk1_value, p_pk2_value, p_pk3_value, p_pk4_value, p_pk5_value,
                p_category_code, l_seq)
        returning attached_document_id into l_att_id;
        return l_att_id;
    end add_text;

    procedure add_version(p_attached_document_id in number,
                          p_temp_file_name       in varchar2,
                          p_document_date        in date default null,
                          p_expiry_date          in date default null,
                          p_page_id              in number   default null) is
        l_ad       xxfnd_attached_documents%rowtype;
        l_old      xxfnd_documents%rowtype;
        l_cfg      xxfnd_storage_config%rowtype;
        l_blob     blob;
        l_filename varchar2(400);
        l_mime     varchar2(255);
        l_stored   t_stored;
        l_doc_id   number;
        l_title    varchar2(400);
        l_desc     varchar2(2000);
    begin
        select * into l_ad from xxfnd_attached_documents
         where attached_document_id = p_attached_document_id and expiration_date is null
           for update;
        select * into l_old from xxfnd_documents where document_id = l_ad.document_id;
        if l_old.datatype_code <> 'FILE' then
            raise_application_error(-20315, 'Only file attachments have versions.');
        end if;
        check_category_rules(l_ad.category_code, p_document_date, p_expiry_date);
        get_temp_file(p_temp_file_name, l_blob, l_filename, l_mime);
        check_upload(p_page_id, l_ad.category_code, l_filename, l_blob);

        -- Same store as the first version so the external history stays together.
        if l_old.storage_type = xxfnd_attach_store_pkg.c_database then
            l_cfg := xxfnd_attach_store_pkg.database_config;
        else
            select * into l_cfg from xxfnd_storage_config where storage_config_id = l_old.storage_config_id;
        end if;
        begin
            select title, description into l_title, l_desc
              from xxfnd_documents_tl
             where document_id = l_old.document_id and language_code = xxfnd_util_pkg.current_lang;
        exception
            when no_data_found then null;
        end;

        l_stored := store_file(l_cfg, l_ad.entity_name, l_ad.pk1_value, l_ad.pk2_value, l_ad.pk3_value,
                               l_ad.pk4_value, l_ad.pk5_value, l_ad.category_code, l_blob, l_filename, l_mime,
                               nvl(l_title, l_filename), l_old.external_document_id);

        insert into xxfnd_documents (category_code, datatype_code, base_document_id, version_number,
                                     storage_config_id, storage_type, external_document_id, external_version_id,
                                     external_url, file_name, mime_type, file_size_bytes, document_date,
                                     expiry_date, upload_status)
        values (l_old.category_code, 'FILE', nvl(l_old.base_document_id, l_old.document_id), l_old.version_number + 1,
                l_cfg.storage_config_id, l_cfg.storage_type, l_stored.external_document_id,
                l_stored.external_version_id, l_stored.external_url, l_filename, l_mime,
                dbms_lob.getlength(l_blob), p_document_date, p_expiry_date, 'STORED')
        returning document_id into l_doc_id;
        set_tl(l_doc_id, nvl(l_title, l_filename), l_desc);

        update xxfnd_attached_documents set document_id = l_doc_id
         where attached_document_id = p_attached_document_id;
    end add_version;

    procedure update_details(p_attached_document_id in number,
                             p_title                in varchar2,
                             p_description          in varchar2,
                             p_document_date        in date,
                             p_expiry_date          in date,
                             p_seq_num              in number default null) is
        l_ad xxfnd_attached_documents%rowtype;
    begin
        select * into l_ad from xxfnd_attached_documents
         where attached_document_id = p_attached_document_id and expiration_date is null
           for update;
        check_category_rules(l_ad.category_code, p_document_date, p_expiry_date);
        update xxfnd_documents
           set document_date = p_document_date, expiry_date = p_expiry_date
         where document_id = l_ad.document_id;
        set_tl(l_ad.document_id, p_title, p_description);
        if p_seq_num is not null then
            update xxfnd_attached_documents set seq_num = p_seq_num
             where attached_document_id = p_attached_document_id;
        end if;
    end update_details;

    procedure remove(p_attached_document_id in number) is
    begin
        update xxfnd_attached_documents
           set expiration_date = systimestamp
         where attached_document_id = p_attached_document_id
           and expiration_date is null;
        if sql%rowcount = 0 then
            raise_application_error(-20316, 'This attachment has already been removed.');
        end if;
    end remove;

    procedure download(p_document_id in number, p_inline in varchar2 default 'N') is
        l_doc  xxfnd_documents%rowtype;
        l_blob blob;
        l_pk1  varchar2(150);
        l_ent  varchar2(60);
        l_newer pls_integer;
    begin
        select * into l_doc from xxfnd_documents where document_id = p_document_id;
        if l_doc.datatype_code <> 'FILE' then
            raise_application_error(-20317, 'This attachment is not a file.');
        end if;
        select max(entity_name), max(pk1_value) into l_ent, l_pk1
          from xxfnd_attached_documents
         where document_id = p_document_id
            or document_id in (select document_id from xxfnd_documents
                                where base_document_id = nvl(l_doc.base_document_id, l_doc.document_id));
        select count(*) into l_newer
          from xxfnd_documents n
         where n.base_document_id = nvl(l_doc.base_document_id, l_doc.document_id)
           and n.version_number > l_doc.version_number;

        l_blob := xxfnd_attach_store_pkg.fetch_file(l_doc, l_newer = 0, l_ent, l_pk1);

        apex_http.download(
            p_blob         => l_blob,
            p_content_type => nvl(l_doc.mime_type, 'application/octet-stream'),
            p_filename     => l_doc.file_name,
            p_is_inline    => p_inline = 'Y');
    end download;

    procedure copy_attachments(p_from_entity in varchar2, p_from_pk1 in varchar2,
                               p_to_entity   in varchar2, p_to_pk1   in varchar2,
                               p_category_code in varchar2 default null) is
    begin
        check_entity(p_to_entity);
        insert into xxfnd_attached_documents (document_id, entity_name, pk1_value, category_code, seq_num,
                                              primary_category_flag)
        select ad.document_id, p_to_entity, p_to_pk1, ad.category_code, ad.seq_num, ad.primary_category_flag
          from xxfnd_attached_documents ad
         where ad.entity_name = p_from_entity
           and ad.pk1_value   = p_from_pk1
           and ad.expiration_date is null
           and (p_category_code is null or ad.category_code = p_category_code)
           and not exists (select 1 from xxfnd_attached_documents x
                            where x.entity_name = p_to_entity and x.pk1_value = p_to_pk1
                              and x.document_id = ad.document_id and x.expiration_date is null);
    end copy_attachments;

end xxfnd_attach_pkg;
/
