--------------------------------------------------------------------------------
-- 07a_xxfnd_attach_store_pkg.sql
-- Document store transport for attachments (0.1): Oracle UCM (WebCenter Content)
-- and SharePoint (Microsoft Graph); DATABASE (xxfnd_document_files) when nothing is configured. Kept apart from XXFND_ATTACH_PKG so the
-- attachment rules and the storage protocols can change independently.
--
--   UCM         POST <base_url>/cs/idcplg  IdcService=CHECKIN_UNIVERSAL (multipart,
--               IsJson=1), GET_FILE by dID. Web Credential: Basic.
--   SharePoint  <base_url> = https://graph.microsoft.com/v1.0
--               PUT /drives/{drive}/root:/{path}/{file}:/content (<= 4 MB) or an
--               upload session in 3.2 MB chunks; a new version is written to the
--               same drive item. Download through @microsoft.graph.downloadUrl, or
--               /versions/{id}/content for an older version.
--               Web Credential: OAuth2 client credentials (scope set on the
--               credential); token URL from XXFND_INTEGRATION_ENDPOINTS.
--
--   Every external call is logged in XXFND_TRANSMISSIONS (purpose
--   DOCUMENT_STORAGE) in an autonomous transaction. File bytes are never logged.
--------------------------------------------------------------------------------

create or replace package xxfnd_attach_store_pkg authid definer as

    c_purpose constant varchar2(30) := 'DOCUMENT_STORAGE';

    type t_stored is record (
        external_document_id varchar2(500),
        external_version_id  varchar2(500),
        external_url         varchar2(2000));

    -- Storage used when no UCM / SharePoint row applies: the file is kept in xxfnd_document_files.
    c_database constant varchar2(30) := 'DATABASE';
    function database_config return xxfnd_storage_config%rowtype;

    -- Stores a file (new document, or a new version when p_previous_external_id is set).
    function upload(p_cfg                  in xxfnd_storage_config%rowtype,
                    p_entity               in varchar2,
                    p_pk1                  in varchar2,
                    p_folder               in varchar2,
                    p_file                 in blob,
                    p_filename             in varchar2,
                    p_mime                 in varchar2,
                    p_title                in varchar2,
                    p_previous_external_id in varchar2) return t_stored;

    -- Reads a stored file. p_is_current = false fetches that exact older version.
    function fetch_file(p_doc        in xxfnd_documents%rowtype,
                        p_is_current in boolean,
                        p_entity     in varchar2,
                        p_pk1        in varchar2) return blob;

end xxfnd_attach_store_pkg;
/

create or replace package body xxfnd_attach_store_pkg as

    c_crlf       constant varchar2(2) := chr(13) || chr(10);
    c_simple_max constant number := 4 * 1024 * 1024;      -- Graph simple-upload limit
    c_chunk      constant number := 10 * 327680;          -- 3.2 MB, multiple of 320 KiB

    function get_endpoint(p_endpoint_code in varchar2) return xxfnd_integration_endpoints%rowtype is
        l_ep xxfnd_integration_endpoints%rowtype;
    begin
        select * into l_ep from xxfnd_integration_endpoints where endpoint_code = p_endpoint_code;
        if l_ep.status_code <> 'ACTIVE' then
            raise_application_error(-20301, 'Storage endpoint ' || p_endpoint_code || ' is not active.');
        end if;
        return l_ep;
    end get_endpoint;

    ----------------------------------------------------------------------------
    -- transmission log (autonomous: survives a page rollback)
    ----------------------------------------------------------------------------
    function log_start(p_endpoint in varchar2, p_entity in varchar2, p_pk1 in varchar2,
                       p_method in varchar2, p_url in varchar2, p_payload in clob) return number is
        pragma autonomous_transaction;
        l_id number;
    begin
        insert into xxfnd_transmissions (endpoint_code, purpose_code, entity_name, pk1_value,
                                         http_method, request_url, request_payload, status_code, created_by)
        values (p_endpoint, c_purpose, p_entity, p_pk1, p_method, substr(p_url, 1, 4000), p_payload,
                'PENDING', xxfnd_util_pkg.current_user)
        returning transmission_id into l_id;
        commit;
        return l_id;
    end log_start;

    procedure log_end(p_id in number, p_status in number, p_response in clob, p_error in varchar2) is
        pragma autonomous_transaction;
        l_resp clob := p_response;
    begin
        -- Keep the log small: the first 8000 characters are enough to diagnose a failure.
        if dbms_lob.getlength(p_response) > 8000 then
            l_resp := dbms_lob.substr(p_response, 8000, 1);
        end if;
        update xxfnd_transmissions
           set response_status_code = p_status,
               response_payload     = l_resp,
               status_code          = case when p_error is null then 'SUCCESS' else 'FAILED' end,
               error_message        = substr(p_error, 1, 4000),
               responded_date       = systimestamp
         where transmission_id = p_id;
        commit;
    end log_end;

    -- URL-encode each path segment, keep the slashes.
    function encode_path(p_path in varchar2) return varchar2 is
        l_parts apex_t_varchar2 := apex_string.split(p_path, '/');
        l_out   varchar2(4000);
    begin
        for i in 1 .. l_parts.count loop
            if l_parts(i) is not null then
                l_out := l_out || case when l_out is not null then '/' end
                      || utl_url.escape(l_parts(i), true, 'AL32UTF8');
            end if;
        end loop;
        return l_out;
    end encode_path;

    procedure raise_http(p_what in varchar2, p_body in clob) is
    begin
        raise_application_error(-20310, p_what || ' failed (HTTP ' || apex_web_service.g_status_code || '): '
            || dbms_lob.substr(p_body, 500, 1));
    end raise_http;

    ----------------------------------------------------------------------------
    -- UCM (WebCenter Content)
    ----------------------------------------------------------------------------
    procedure add_part(p_body in out nocopy blob, p_boundary in varchar2, p_name in varchar2, p_value in varchar2) is
    begin
        dbms_lob.append(p_body, utl_i18n.string_to_raw(
            '--' || p_boundary || c_crlf
            || 'Content-Disposition: form-data; name="' || p_name || '"' || c_crlf || c_crlf
            || p_value || c_crlf, 'AL32UTF8'));
    end add_part;

    function ucm_checkin(p_ep in xxfnd_integration_endpoints%rowtype, p_cfg in xxfnd_storage_config%rowtype,
                         p_entity in varchar2, p_pk1 in varchar2, p_folder in varchar2,
                         p_file in blob, p_filename in varchar2, p_mime in varchar2,
                         p_title in varchar2, p_existing_doc_name in varchar2) return t_stored is
        l_boundary varchar2(60) := 'xxfnd' || rawtohex(sys_guid());
        l_body     blob;
        l_url      varchar2(2000) := rtrim(p_ep.base_url, '/') || '/cs/idcplg';
        l_resp     clob;
        l_json     json_object_t;
        l_local    json_object_t;
        l_log_id   number;
        l_stored   t_stored;
        l_status   varchar2(30);
        l_meta     json_object_t;
    begin
        dbms_lob.createtemporary(l_body, true);
        add_part(l_body, l_boundary, 'IdcService', 'CHECKIN_UNIVERSAL');
        add_part(l_body, l_boundary, 'IsJson', '1');
        add_part(l_body, l_boundary, 'dDocTitle', substr(nvl(p_title, p_filename), 1, 255));
        add_part(l_body, l_boundary, 'dDocType', nvl(p_cfg.ucm_doc_type, 'Document'));
        add_part(l_body, l_boundary, 'dSecurityGroup', p_cfg.ucm_security_group);
        if p_cfg.ucm_doc_account is not null then
            add_part(l_body, l_boundary, 'dDocAccount', p_cfg.ucm_doc_account);
        end if;
        add_part(l_body, l_boundary, 'dDocAuthor', xxfnd_util_pkg.current_user);
        add_part(l_body, l_boundary, 'xComments', substr(p_folder, 1, 255));
        if p_existing_doc_name is not null then
            add_part(l_body, l_boundary, 'dDocName', p_existing_doc_name);   -- new revision
        end if;
        dbms_lob.append(l_body, utl_i18n.string_to_raw(
            '--' || l_boundary || c_crlf
            || 'Content-Disposition: form-data; name="primaryFile"; filename="' || replace(p_filename, '"', '') || '"' || c_crlf
            || 'Content-Type: ' || nvl(p_mime, 'application/octet-stream') || c_crlf || c_crlf, 'AL32UTF8'));
        dbms_lob.append(l_body, p_file);
        dbms_lob.append(l_body, utl_i18n.string_to_raw(c_crlf || '--' || l_boundary || '--' || c_crlf, 'AL32UTF8'));

        l_meta := json_object_t();
        l_meta.put('service', 'CHECKIN_UNIVERSAL');
        l_meta.put('fileName', p_filename);
        l_meta.put('bytes', dbms_lob.getlength(p_file));
        l_meta.put('revisionOf', p_existing_doc_name);
        l_log_id := log_start(p_ep.endpoint_code, p_entity, p_pk1, 'POST', l_url, l_meta.to_clob);

        apex_web_service.clear_request_headers;
        apex_web_service.set_request_headers(
            p_name_01  => 'Content-Type',
            p_value_01 => 'multipart/form-data; boundary=' || l_boundary,
            p_reset    => true);
        begin
            l_resp := apex_web_service.make_rest_request(
                          p_url                  => l_url,
                          p_http_method          => 'POST',
                          p_body_blob            => l_body,
                          p_credential_static_id => p_ep.web_credential_static_id);
        exception
            when others then
                log_end(l_log_id, null, null, sqlerrm);
                raise;
        end;

        if apex_web_service.g_status_code not between 200 and 299 then
            log_end(l_log_id, apex_web_service.g_status_code, l_resp, 'HTTP ' || apex_web_service.g_status_code);
            raise_http('UCM check-in', l_resp);
        end if;

        l_json   := json_object_t.parse(l_resp);
        l_local  := l_json.get_object('LocalData');
        l_status := l_local.get_string('StatusCode');
        if nvl(l_status, '0') <> '0' then
            log_end(l_log_id, apex_web_service.g_status_code, l_resp, l_local.get_string('StatusMessage'));
            raise_application_error(-20311, 'UCM check-in failed: ' || l_local.get_string('StatusMessage'));
        end if;

        l_stored.external_document_id := l_local.get_string('dDocName');
        l_stored.external_version_id  := l_local.get_string('dID');
        l_stored.external_url         := rtrim(p_ep.base_url, '/') || '/cs/idcplg?IdcService=DOC_INFO&dID='
                                         || l_stored.external_version_id;
        log_end(l_log_id, apex_web_service.g_status_code, l_resp, null);
        dbms_lob.freetemporary(l_body);
        return l_stored;
    end ucm_checkin;

    function ucm_get_file(p_ep in xxfnd_integration_endpoints%rowtype, p_dId in varchar2,
                          p_entity in varchar2, p_pk1 in varchar2) return blob is
        l_url    varchar2(2000) := rtrim(p_ep.base_url, '/') || '/cs/idcplg?IdcService=GET_FILE&dID='
                                   || utl_url.escape(p_dId, true);
        l_blob   blob;
        l_log_id number := log_start(p_ep.endpoint_code, p_entity, p_pk1, 'GET', l_url, null);
    begin
        apex_web_service.clear_request_headers;
        l_blob := apex_web_service.make_rest_request_b(
                      p_url                  => l_url,
                      p_http_method          => 'GET',
                      p_credential_static_id => p_ep.web_credential_static_id);
        if apex_web_service.g_status_code not between 200 and 299 then
            log_end(l_log_id, apex_web_service.g_status_code, null, 'HTTP ' || apex_web_service.g_status_code);
            raise_http('UCM download', null);
        end if;
        log_end(l_log_id, apex_web_service.g_status_code, null, null);
        return l_blob;
    end ucm_get_file;

    ----------------------------------------------------------------------------
    -- SharePoint (Microsoft Graph)
    ----------------------------------------------------------------------------
    -- Graph calls pass the Web Credential and token URL; APEX obtains and caches
    -- the OAuth2 client-credentials token itself, using the scope configured on
    -- the Web Credential (XXFND_INTEGRATION_ENDPOINTS.OAUTH_SCOPE records it).
    procedure graph_auth(p_ep in xxfnd_integration_endpoints%rowtype) is
    begin
        if p_ep.oauth_token_url is null then
            raise_application_error(-20318, 'Endpoint ' || p_ep.endpoint_code || ' needs an OAuth token URL.');
        end if;
        apex_web_service.clear_request_headers;
    end graph_auth;

    function graph_item(p_resp in clob, p_url in varchar2) return t_stored is
        l_item   json_object_t := json_object_t.parse(p_resp);
        l_stored t_stored;
    begin
        l_stored.external_document_id := l_item.get_string('id');
        l_stored.external_version_id  := l_item.get_string('eTag');
        l_stored.external_url         := l_item.get_string('webUrl');
        return l_stored;
    end graph_item;

    function sp_upload(p_ep in xxfnd_integration_endpoints%rowtype, p_cfg in xxfnd_storage_config%rowtype,
                       p_entity in varchar2, p_pk1 in varchar2, p_folder in varchar2,
                       p_file in blob, p_filename in varchar2, p_mime in varchar2,
                       p_existing_item_id in varchar2) return t_stored is
        l_base    varchar2(2000) := rtrim(p_ep.base_url, '/') || '/drives/' || p_cfg.sharepoint_drive_id;
        l_target  varchar2(4000);
        l_size    number := dbms_lob.getlength(p_file);
        l_resp    clob;
        l_log_id  number;
        l_session varchar2(4000);
        l_offset  number := 1;
        l_len     number;
        l_chunk   blob;
        l_meta    json_object_t;
        l_stored  t_stored;
    begin
        -- Existing item = new version of the same file; otherwise a path under the folder.
        l_target := case when p_existing_item_id is not null
                         then l_base || '/items/' || p_existing_item_id
                         else l_base || '/root:/' || encode_path(p_folder || '/' || p_filename) || ':' end;

        l_meta := json_object_t();
        l_meta.put('fileName', p_filename);
        l_meta.put('bytes', l_size);
        l_meta.put('folder', p_folder);
        l_meta.put('versionOf', p_existing_item_id);
        l_log_id := log_start(p_ep.endpoint_code, p_entity, p_pk1,
                              case when l_size <= c_simple_max then 'PUT' else 'POST' end, l_target,
                              l_meta.to_clob);
        begin
            graph_auth(p_ep);
            if l_size <= c_simple_max then
                apex_web_service.set_request_headers(
                    p_name_01 => 'Content-Type', p_value_01 => nvl(p_mime, 'application/octet-stream'),
                    p_reset   => false);
                l_resp := apex_web_service.make_rest_request(
                              p_url => l_target || '/content', p_http_method => 'PUT', p_body_blob => p_file,
                              p_credential_static_id => p_ep.web_credential_static_id,
                              p_token_url            => p_ep.oauth_token_url);
                if apex_web_service.g_status_code not in (200, 201) then
                    log_end(l_log_id, apex_web_service.g_status_code, l_resp, 'HTTP ' || apex_web_service.g_status_code);
                    raise_http('SharePoint upload', l_resp);
                end if;
            else
                apex_web_service.set_request_headers(
                    p_name_01 => 'Content-Type', p_value_01 => 'application/json', p_reset => false);
                l_resp := apex_web_service.make_rest_request(
                              p_url         => l_target || '/createUploadSession',
                              p_http_method => 'POST',
                              p_body        => '{"item":{"@microsoft.graph.conflictBehavior":"replace"}}',
                              p_credential_static_id => p_ep.web_credential_static_id,
                              p_token_url            => p_ep.oauth_token_url);
                if apex_web_service.g_status_code not in (200, 201) then
                    log_end(l_log_id, apex_web_service.g_status_code, l_resp, 'HTTP ' || apex_web_service.g_status_code);
                    raise_http('SharePoint upload session', l_resp);
                end if;
                l_session := json_object_t.parse(l_resp).get_string('uploadUrl');

                -- The upload URL is pre-authorised; Graph rejects an Authorization header on it.
                while l_offset <= l_size loop
                    l_len := least(c_chunk, l_size - l_offset + 1);
                    dbms_lob.createtemporary(l_chunk, true);
                    dbms_lob.copy(l_chunk, p_file, l_len, 1, l_offset);
                    apex_web_service.clear_request_headers;
                    apex_web_service.set_request_headers(
                        p_name_01  => 'Content-Range',
                        p_value_01 => 'bytes ' || (l_offset - 1) || '-' || (l_offset + l_len - 2) || '/' || l_size,
                        p_reset    => true);
                    l_resp := apex_web_service.make_rest_request(
                                  p_url => l_session, p_http_method => 'PUT', p_body_blob => l_chunk);
                    dbms_lob.freetemporary(l_chunk);
                    if apex_web_service.g_status_code not in (200, 201, 202) then
                        log_end(l_log_id, apex_web_service.g_status_code, l_resp, 'HTTP ' || apex_web_service.g_status_code);
                        raise_http('SharePoint chunk upload', l_resp);
                    end if;
                    l_offset := l_offset + l_len;
                end loop;
            end if;
        exception
            when others then
                if sqlcode not in (-20310) then
                    log_end(l_log_id, apex_web_service.g_status_code, l_resp, sqlerrm);
                end if;
                raise;
        end;
        log_end(l_log_id, apex_web_service.g_status_code, l_resp, null);
        l_stored := graph_item(l_resp, l_target);

        -- Record the SharePoint version ID so an older version can be downloaded later.
        begin
            graph_auth(p_ep);
            l_resp := apex_web_service.make_rest_request(
                          p_url         => l_base || '/items/' || l_stored.external_document_id
                                           || '/versions?$select=id&$top=1',
                          p_http_method => 'GET',
                          p_credential_static_id => p_ep.web_credential_static_id,
                          p_token_url            => p_ep.oauth_token_url);
            if apex_web_service.g_status_code = 200 then
                l_stored.external_version_id := nvl(
                    treat(json_object_t.parse(l_resp).get_array('value').get(0) as json_object_t).get_string('id'),
                    l_stored.external_version_id);
            end if;
        exception
            when others then
                null;   -- keep the eTag; downloads of the current version do not need the version ID
        end;
        return l_stored;
    end sp_upload;

    function sp_download(p_ep in xxfnd_integration_endpoints%rowtype, p_cfg in xxfnd_storage_config%rowtype,
                         p_item_id in varchar2, p_version_id in varchar2, p_is_current in boolean,
                         p_entity in varchar2, p_pk1 in varchar2) return blob is
        l_url    varchar2(2000) := rtrim(p_ep.base_url, '/') || '/drives/' || p_cfg.sharepoint_drive_id
                                   || '/items/' || p_item_id || '?$select=id,@microsoft.graph.downloadUrl';
        l_resp   clob;
        l_dl     varchar2(4000);
        l_blob   blob;
        l_log_id number;
    begin
        if not p_is_current and p_version_id is not null and p_version_id not like '"%' then
            -- Older version: Graph redirects /versions/{id}/content to the file.
            l_url := rtrim(p_ep.base_url, '/') || '/drives/' || p_cfg.sharepoint_drive_id
                  || '/items/' || p_item_id || '/versions/' || utl_url.escape(p_version_id, true) || '/content';
            l_log_id := log_start(p_ep.endpoint_code, p_entity, p_pk1, 'GET', l_url, null);
            graph_auth(p_ep);
            l_blob := apex_web_service.make_rest_request_b(p_url => l_url, p_http_method => 'GET',
                          p_credential_static_id => p_ep.web_credential_static_id,
                          p_token_url            => p_ep.oauth_token_url);
            log_end(l_log_id, apex_web_service.g_status_code, null,
                    case when apex_web_service.g_status_code <> 200 then 'HTTP ' || apex_web_service.g_status_code end);
            if apex_web_service.g_status_code <> 200 then
                raise_http('SharePoint version download', null);
            end if;
            return l_blob;
        end if;

        l_log_id := log_start(p_ep.endpoint_code, p_entity, p_pk1, 'GET', l_url, null);
        graph_auth(p_ep);
        l_resp := apex_web_service.make_rest_request(p_url => l_url, p_http_method => 'GET',
                      p_credential_static_id => p_ep.web_credential_static_id,
                      p_token_url            => p_ep.oauth_token_url);
        if apex_web_service.g_status_code <> 200 then
            log_end(l_log_id, apex_web_service.g_status_code, l_resp, 'HTTP ' || apex_web_service.g_status_code);
            raise_http('SharePoint download', l_resp);
        end if;
        l_dl := json_object_t.parse(l_resp).get_string('@microsoft.graph.downloadUrl');
        apex_web_service.clear_request_headers;     -- short-lived pre-authorised URL
        l_blob := apex_web_service.make_rest_request_b(p_url => l_dl, p_http_method => 'GET');
        log_end(l_log_id, apex_web_service.g_status_code, null,
                case when apex_web_service.g_status_code <> 200 then 'HTTP ' || apex_web_service.g_status_code end);
        if apex_web_service.g_status_code <> 200 then
            raise_http('SharePoint download', null);
        end if;
        return l_blob;
    end sp_download;

    ----------------------------------------------------------------------------
    -- public
    ----------------------------------------------------------------------------
    function database_config return xxfnd_storage_config%rowtype is
        l_cfg xxfnd_storage_config%rowtype;
    begin
        l_cfg.storage_type := c_database;
        return l_cfg;
    end database_config;

    function upload(p_cfg                  in xxfnd_storage_config%rowtype,
                    p_entity               in varchar2,
                    p_pk1                  in varchar2,
                    p_folder               in varchar2,
                    p_file                 in blob,
                    p_filename             in varchar2,
                    p_mime                 in varchar2,
                    p_title                in varchar2,
                    p_previous_external_id in varchar2) return t_stored is
        l_ep     xxfnd_integration_endpoints%rowtype;
        l_stored t_stored;
    begin
        if p_cfg.storage_type = c_database then
            insert into xxfnd_document_files (file_content) values (p_file)
            returning to_char(file_id) into l_stored.external_document_id;
            l_stored.external_version_id := l_stored.external_document_id;
            return l_stored;
        end if;
        l_ep := get_endpoint(p_cfg.endpoint_code);
        if p_cfg.storage_type = 'UCM' then
            return ucm_checkin(l_ep, p_cfg, p_entity, p_pk1, p_folder, p_file, p_filename, p_mime,
                               p_title, p_previous_external_id);
        end if;
        return sp_upload(l_ep, p_cfg, p_entity, p_pk1, p_folder, p_file, p_filename, p_mime,
                         p_previous_external_id);
    end upload;

    function fetch_file(p_doc        in xxfnd_documents%rowtype,
                        p_is_current in boolean,
                        p_entity     in varchar2,
                        p_pk1        in varchar2) return blob is
        l_cfg xxfnd_storage_config%rowtype;
        l_ep  xxfnd_integration_endpoints%rowtype;
        l_blob blob;
    begin
        if p_doc.storage_type = c_database then
            select file_content into l_blob from xxfnd_document_files where file_id = to_number(p_doc.external_version_id);
            return l_blob;
        end if;
        select * into l_cfg from xxfnd_storage_config where storage_config_id = p_doc.storage_config_id;
        select * into l_ep  from xxfnd_integration_endpoints where endpoint_code = l_cfg.endpoint_code;
        if p_doc.storage_type = 'UCM' then
            return ucm_get_file(l_ep, p_doc.external_version_id, p_entity, p_pk1);
        end if;
        return sp_download(l_ep, l_cfg, p_doc.external_document_id, p_doc.external_version_id,
                           p_is_current, p_entity, p_pk1);
    end fetch_file;

end xxfnd_attach_store_pkg;
/
