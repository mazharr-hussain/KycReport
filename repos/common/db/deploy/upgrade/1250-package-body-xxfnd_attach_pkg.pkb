
create or replace package body xxfnd_attach_pkg as

    -- application defaults when the ATTACH_* application settings are empty
    c_default_size_mb constant number        := 10;
    c_default_types   constant varchar2(200) := 'pdf,jpg,jpeg,png,tif,tiff,doc,docx,xls,xlsx,msg,eml';

    ----------------------------------------------------------------------------
    -- release 81: the document store transport (was XXFND_ATTACH_STORE_PKG, 13): Oracle UCM (WebCenter Content)
    -- and SharePoint (Microsoft Graph); DATABASE (xxfnd_document_files) when nothing is configured.
    -- and SharePoint (Microsoft Graph); DATABASE (xxfnd_document_files) when nothing is configured. Kept apart from XXFND_ATTACH_PKG so the
    -- attachment rules and the storage protocols can change independently.
    --   UCM         POST <base_url>/cs/idcplg  IdcService=CHECKIN_UNIVERSAL (multipart,
    --               IsJson=1), GET_FILE by dID. Web Credential: Basic.
    --   SharePoint  <base_url> = https://graph.microsoft.com/v1.0
    --               PUT /drives/{drive}/root:/{path}/{file}:/content (<= 4 MB) or an
    --               upload session in 3.2 MB chunks; a new version is written to the
    --               same drive item. Download through @microsoft.graph.downloadUrl, or
    --               /versions/{id}/content for an older version.
    --               Web Credential: OAuth2 client credentials (scope set on the
    --               credential); token URL from the server (XXFND_SERVERS, release 86).
    --   Object      release 86: OCI Object Storage. <base_url> = the server's Remote Server URL, else
    --   Storage     https://objectstorage.<region>.oraclecloud.com; PUT / GET / DELETE
    --               /n/{namespace}/b/{bucket}/o/{object name}; each version is its own object
    --               (OBJECT_NAME). Web Credential: OCI native authentication.
    --   Every external call is logged in the COMMON call log (XXFND_INTEGRATION_PKG.LOG_START / LOG_END, purpose
    --   DOCUMENT_STORAGE) in an autonomous transaction. File bytes are never logged.
    ----------------------------------------------------------------------------
    c_purpose  constant varchar2(30) := 'DOCUMENT_STORAGE';
    c_database constant varchar2(30) := 'DATABASE';
    type t_stored is record (
        external_document_id varchar2(500),
        external_version_id  varchar2(500),
        external_url         varchar2(2000));


    c_crlf       constant varchar2(2) := chr(13) || chr(10);
    c_simple_max constant number := 4 * 1024 * 1024;      -- Graph simple-upload limit
    c_chunk      constant number := 10 * 327680;          -- 3.2 MB, multiple of 320 KiB

    -- release 83: the store's server comes from XXFND_INTEGRATION_PKG; release 86: the workspace server
    -- (XXFND_SERVERS: its APEX Remote Server and Web Credential, OAuth token URL, OCI region and namespace)
    subtype t_server is xxfnd_integration_pkg.t_server;
    function get_server(p_server_code in varchar2) return t_server is
    begin
        return xxfnd_integration_pkg.server(p_server_code);
    end get_server;

    ----------------------------------------------------------------------------
    -- transmission log: release 83 - the COMMON call log (XXFND_INTEGRATION_PKG, autonomous); file transfers are
    -- logged, not retried. The HTTP details are in APEX_WEBSERVICE_LOG.
    ----------------------------------------------------------------------------
    function log_start(p_endpoint in varchar2, p_entity in varchar2, p_pk1 in varchar2,
                       p_method in varchar2, p_url in varchar2, p_payload in clob) return number is
    begin
        return xxfnd_integration_pkg.log_start(p_endpoint, p_method, p_url, p_entity, p_pk1, c_purpose);
    end log_start;

    procedure log_end(p_id in number, p_status in number, p_response in clob, p_error in varchar2) is
    begin
        xxfnd_integration_pkg.log_end(p_id, p_status, p_error);
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

    function ucm_checkin(p_ep in t_server, p_cfg in xxfnd_storage_config%rowtype,
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
        l_log_id := log_start(p_ep.static_id, p_entity, p_pk1, 'POST', l_url, l_meta.to_clob);

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
                          p_credential_static_id => p_ep.credential_static_id);
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

    function ucm_get_file(p_ep in t_server, p_dId in varchar2,
                          p_entity in varchar2, p_pk1 in varchar2) return blob is
        l_url    varchar2(2000) := rtrim(p_ep.base_url, '/') || '/cs/idcplg?IdcService=GET_FILE&dID='
                                   || utl_url.escape(p_dId, true);
        l_blob   blob;
        l_log_id number := log_start(p_ep.static_id, p_entity, p_pk1, 'GET', l_url, null);
    begin
        apex_web_service.clear_request_headers;
        l_blob := apex_web_service.make_rest_request_b(
                      p_url                  => l_url,
                      p_http_method          => 'GET',
                      p_credential_static_id => p_ep.credential_static_id);
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
    -- the Web Credential (the token URL is on the server, XXFND_SERVERS.OAUTH_TOKEN_URL).
    procedure graph_auth(p_ep in t_server) is
    begin
        if p_ep.oauth_token_url is null then
            raise_application_error(-20318, 'Server ' || p_ep.static_id || ' needs an OAuth token URL.');
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

    function sp_upload(p_ep in t_server, p_cfg in xxfnd_storage_config%rowtype,
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
        l_log_id := log_start(p_ep.static_id, p_entity, p_pk1,
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
                              p_credential_static_id => p_ep.credential_static_id,
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
                              p_credential_static_id => p_ep.credential_static_id,
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
                          p_credential_static_id => p_ep.credential_static_id,
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

    function sp_download(p_ep in t_server, p_cfg in xxfnd_storage_config%rowtype,
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
            l_log_id := log_start(p_ep.static_id, p_entity, p_pk1, 'GET', l_url, null);
            graph_auth(p_ep);
            l_blob := apex_web_service.make_rest_request_b(p_url => l_url, p_http_method => 'GET',
                          p_credential_static_id => p_ep.credential_static_id,
                          p_token_url            => p_ep.oauth_token_url);
            log_end(l_log_id, apex_web_service.g_status_code, null,
                    case when apex_web_service.g_status_code <> 200 then 'HTTP ' || apex_web_service.g_status_code end);
            if apex_web_service.g_status_code <> 200 then
                raise_http('SharePoint version download', null);
            end if;
            return l_blob;
        end if;

        l_log_id := log_start(p_ep.static_id, p_entity, p_pk1, 'GET', l_url, null);
        graph_auth(p_ep);
        l_resp := apex_web_service.make_rest_request(p_url => l_url, p_http_method => 'GET',
                      p_credential_static_id => p_ep.credential_static_id,
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
    ----------------------------------------------------------------------------
    -- release 86: OCI Object Storage (PUT / GET / DELETE of an object with the server's Web Credential)
    ----------------------------------------------------------------------------
    function os_base(p_srv in t_server, p_bucket in varchar2) return varchar2 is
    begin
        if p_srv.oci_namespace is null or p_bucket is null then
            raise_application_error(-20336, 'OCI Object Storage needs the namespace (server ' || p_srv.static_id
                || ') and the bucket.');
        end if;
        return rtrim(coalesce(p_srv.base_url, 'https://objectstorage.' || p_srv.oci_region || '.oraclecloud.com'), '/')
            || '/n/' || utl_url.escape(p_srv.oci_namespace, true, 'AL32UTF8')
            || '/b/' || utl_url.escape(p_bucket, true, 'AL32UTF8') || '/o';
    end os_base;

    function os_object_url(p_srv in t_server, p_bucket in varchar2, p_object in varchar2) return varchar2 is
    begin
        -- the whole object name is one path segment: its slashes are encoded too
        return os_base(p_srv, p_bucket) || '/' || utl_url.escape(p_object, true, 'AL32UTF8');
    end os_object_url;

    function os_put(p_srv in t_server, p_bucket in varchar2, p_object in varchar2, p_file in blob, p_mime in varchar2,
                    p_entity in varchar2, p_pk1 in varchar2) return t_stored is
        l_url    varchar2(4000) := os_object_url(p_srv, p_bucket, p_object);
        l_resp   clob;
        l_log_id number := log_start(p_srv.static_id, p_entity, p_pk1, 'PUT', l_url, null);
        l_stored t_stored;
    begin
        apex_web_service.clear_request_headers;
        apex_web_service.set_request_headers(p_name_01  => 'Content-Type',
                                             p_value_01 => nvl(p_mime, 'application/octet-stream'),
                                             p_reset    => true);
        begin
            l_resp := apex_web_service.make_rest_request(p_url                  => l_url,
                                                         p_http_method          => 'PUT',
                                                         p_body_blob            => p_file,
                                                         p_credential_static_id => p_srv.credential_static_id);
        exception
            when others then
                log_end(l_log_id, null, null, sqlerrm);
                raise;
        end;
        if apex_web_service.g_status_code not between 200 and 299 then
            log_end(l_log_id, apex_web_service.g_status_code, l_resp, 'HTTP ' || apex_web_service.g_status_code);
            raise_http('Object Storage upload', l_resp);
        end if;
        l_stored.external_document_id := p_object;
        l_stored.external_version_id  := p_object;
        for i in 1 .. apex_web_service.g_headers.count loop
            if lower(apex_web_service.g_headers(i).name) = 'etag' then
                l_stored.external_version_id := substr(apex_web_service.g_headers(i).value, 1, 500);
            end if;
        end loop;
        l_stored.external_url := substr(l_url, 1, 2000);
        log_end(l_log_id, apex_web_service.g_status_code, l_resp, null);
        return l_stored;
    end os_put;

    function os_get(p_srv in t_server, p_bucket in varchar2, p_object in varchar2,
                    p_entity in varchar2, p_pk1 in varchar2) return blob is
        l_url    varchar2(4000) := os_object_url(p_srv, p_bucket, p_object);
        l_blob   blob;
        l_log_id number := log_start(p_srv.static_id, p_entity, p_pk1, 'GET', l_url, null);
    begin
        apex_web_service.clear_request_headers;
        begin
            l_blob := apex_web_service.make_rest_request_b(p_url                  => l_url,
                                                           p_http_method          => 'GET',
                                                           p_credential_static_id => p_srv.credential_static_id);
        exception
            when others then
                log_end(l_log_id, null, null, sqlerrm);
                raise;
        end;
        if apex_web_service.g_status_code <> 200 then
            log_end(l_log_id, apex_web_service.g_status_code, null, 'HTTP ' || apex_web_service.g_status_code);
            raise_http('Object Storage download', null);
        end if;
        log_end(l_log_id, apex_web_service.g_status_code, null, null);
        return l_blob;
    end os_get;

    -- removes a stored object (e.g. the object of an upload whose document could not be saved)
    procedure os_delete(p_srv in t_server, p_bucket in varchar2, p_object in varchar2,
                        p_entity in varchar2, p_pk1 in varchar2) is
        l_url    varchar2(4000) := os_object_url(p_srv, p_bucket, p_object);
        l_resp   clob;
        l_log_id number := log_start(p_srv.static_id, p_entity, p_pk1, 'DELETE', l_url, null);
    begin
        apex_web_service.clear_request_headers;
        l_resp := apex_web_service.make_rest_request(p_url                  => l_url,
                                                     p_http_method          => 'DELETE',
                                                     p_credential_static_id => p_srv.credential_static_id);
        log_end(l_log_id, apex_web_service.g_status_code, l_resp,
                case when apex_web_service.g_status_code not between 200 and 299
                     then 'HTTP ' || apex_web_service.g_status_code end);
    exception
        when others then
            log_end(l_log_id, null, null, sqlerrm);   -- best effort: the document was not saved anyway
    end os_delete;

    ----------------------------------------------------------------------------
    -- public
    ----------------------------------------------------------------------------
    function database_config return xxfnd_storage_config%rowtype is
        l_cfg xxfnd_storage_config%rowtype;
    begin
        l_cfg.storage_type := c_database;
        return l_cfg;
    end database_config;

    -- release 86: a storage row read past the administration scope (a document of any application may be read)
    function config_row(p_storage_config_id in number) return xxfnd_storage_config%rowtype is
        l_cfg xxfnd_storage_config%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select * into l_cfg from xxfnd_storage_config where storage_config_id = p_storage_config_id;
        exception
            when no_data_found then
                null;
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        return l_cfg;
    end config_row;

    -- release 86: where an existing document is: its own server and container (library / bucket) when recorded,
    -- else those of the storage row it was stored by (documents stored before release 86)
    function document_location(p_doc in xxfnd_documents%rowtype) return xxfnd_storage_config%rowtype is
        l_cfg xxfnd_storage_config%rowtype;
    begin
        if p_doc.storage_config_id is not null then
            l_cfg := config_row(p_doc.storage_config_id);
        end if;
        l_cfg.storage_type := p_doc.storage_type;
        l_cfg.server_code  := coalesce(p_doc.server_code, l_cfg.server_code, l_cfg.endpoint_code);
        if p_doc.storage_type = 'SHAREPOINT' then
            l_cfg.sharepoint_drive_id := coalesce(p_doc.storage_container, l_cfg.sharepoint_drive_id);
        elsif p_doc.storage_type = 'OBJECT_STORAGE' then
            l_cfg.bucket_name := coalesce(p_doc.storage_container, l_cfg.bucket_name);
        end if;
        return l_cfg;
    end document_location;

    -- the library (SharePoint) or bucket (Object Storage) a file is stored in, kept on the document
    function storage_container(p_cfg in xxfnd_storage_config%rowtype) return varchar2 is
    begin
        return case p_cfg.storage_type when 'SHAREPOINT'     then p_cfg.sharepoint_drive_id
                                       when 'OBJECT_STORAGE' then p_cfg.bucket_name end;
    end storage_container;

    function object_name(p_folder in varchar2, p_file_name in varchar2) return varchar2 is
    begin
        return case when trim(both '/' from p_folder) is not null then trim(both '/' from p_folder) || '/' end
            || lower(substr(rawtohex(sys_guid()), 1, 12)) || '_' || replace(nvl(p_file_name, 'file'), '/', '_');
    end object_name;

    function object_storage_url(p_server_code in varchar2, p_bucket in varchar2,
                                p_object_name in varchar2 default null) return varchar2 is
        l_srv t_server := get_server(p_server_code);
    begin
        return case when p_object_name is null then os_base(l_srv, p_bucket)
                    else os_object_url(l_srv, p_bucket, p_object_name) end;
    end object_storage_url;

    function upload(p_cfg                  in xxfnd_storage_config%rowtype,
                    p_entity               in varchar2,
                    p_pk1                  in varchar2,
                    p_folder               in varchar2,
                    p_file                 in blob,
                    p_filename             in varchar2,
                    p_mime                 in varchar2,
                    p_title                in varchar2,
                    p_previous_external_id in varchar2) return t_stored is
        l_srv    t_server;
        l_stored t_stored;
    begin
        if p_cfg.storage_type = c_database then
            insert into xxfnd_document_files (file_content) values (p_file)
            returning to_char(file_id) into l_stored.external_document_id;
            l_stored.external_version_id := l_stored.external_document_id;
            return l_stored;
        end if;
        l_srv := get_server(p_cfg.server_code);
        if p_cfg.storage_type = 'UCM' then
            return ucm_checkin(l_srv, p_cfg, p_entity, p_pk1, p_folder, p_file, p_filename, p_mime,
                               p_title, p_previous_external_id);
        elsif p_cfg.storage_type = 'OBJECT_STORAGE' then
            -- every version is its own object: nothing is overwritten
            return os_put(l_srv, p_cfg.bucket_name, object_name(p_folder, p_filename), p_file, p_mime, p_entity, p_pk1);
        end if;
        return sp_upload(l_srv, p_cfg, p_entity, p_pk1, p_folder, p_file, p_filename, p_mime,
                         p_previous_external_id);
    end upload;

    function fetch_file(p_doc        in xxfnd_documents%rowtype,
                        p_is_current in boolean,
                        p_entity     in varchar2,
                        p_pk1        in varchar2) return blob is
        l_cfg  xxfnd_storage_config%rowtype;
        l_srv  t_server;
        l_blob blob;
    begin
        if p_doc.storage_type = c_database then
            select file_content into l_blob from xxfnd_document_files where file_id = to_number(p_doc.external_version_id);
            return l_blob;
        end if;
        l_cfg := document_location(p_doc);
        l_srv := get_server(l_cfg.server_code);
        if p_doc.storage_type = 'UCM' then
            return ucm_get_file(l_srv, p_doc.external_version_id, p_entity, p_pk1);
        elsif p_doc.storage_type = 'OBJECT_STORAGE' then
            return os_get(l_srv, l_cfg.bucket_name, p_doc.external_document_id, p_entity, p_pk1);
        end if;
        return sp_download(l_srv, l_cfg, p_doc.external_document_id, p_doc.external_version_id,
                           p_is_current, p_entity, p_pk1);
    end fetch_file;

    ----------------------------------------------------------------------------
    -- configuration lookups
    ----------------------------------------------------------------------------
    function storage_application(p_entity_name in varchar2, p_category_code in varchar2) return varchar2 is
        l_app varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select coalesce((select max(e.application_code) from xxfnd_document_entities e
                              where e.entity_name = p_entity_name),
                            (select max(c.application_code) from xxfnd_document_categories c
                              where c.category_code = p_category_code))
              into l_app
              from dual;
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        return nvl(upper(l_app), 'COMMON');
    end storage_application;

    function resolve_storage(p_entity_name in varchar2, p_category_code in varchar2)
        return xxfnd_storage_config%rowtype is
        l_app varchar2(30) := storage_application(p_entity_name, p_category_code);
        l_cfg xxfnd_storage_config%rowtype;
        l_v   xxfnd_app_storage_v%rowtype;
    begin
        -- release 86: the category's line of the application, else the application default (XXFND_APP_STORAGE_V
        -- holds the rule); read past the administration scope: every user stores documents
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select * into l_v
              from (select v.* from xxfnd_app_storage_v v
                     where v.application_code = l_app
                       and (v.category_code = p_category_code or v.category_code is null)
                     order by v.category_code nulls last)
             where rownum = 1;
        exception
            when no_data_found then
                l_v.effective_storage_type := c_database;
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        if nvl(l_v.effective_storage_type, c_database) = c_database then
            -- nothing applies, or the setup is incomplete: keep the file in the database
            return database_config;
        end if;
        l_cfg.storage_config_id    := nvl(l_v.storage_config_id, l_v.default_config_id);
        l_cfg.application_code     := case when l_app <> 'COMMON' then l_app end;
        l_cfg.category_code        := p_category_code;
        l_cfg.storage_type         := l_v.effective_storage_type;
        l_cfg.server_code          := l_v.effective_server_code;
        l_cfg.sharepoint_site_id   := l_v.effective_site;
        l_cfg.sharepoint_drive_id  := l_v.effective_library;
        l_cfg.bucket_name          := l_v.effective_bucket;
        l_cfg.ucm_security_group   := l_v.effective_security_group;
        l_cfg.ucm_doc_account      := l_v.effective_account;
        l_cfg.ucm_doc_type         := l_v.effective_document_type;
        l_cfg.folder_path_template := l_v.effective_folder;
        l_cfg.enabled_flag         := 'Y';
        return l_cfg;
    end resolve_storage;

    ---------------------------------------------------------------- release 86: the Storage editor (page 137)
    function storage_app(p_application_code in varchar2) return varchar2 is
        l_n pls_integer;
    begin
        select count(*) into l_n from xxfnd_applications where application_code = upper(p_application_code);
        if l_n = 0 then
            raise_application_error(-20333, 'Application ' || p_application_code || ' is not registered.');
        end if;
        return case when upper(p_application_code) <> 'COMMON' then upper(p_application_code) end;   -- COMMON = instance
    end storage_app;

    function storage_server_type(p_server_code in varchar2) return varchar2 is
        l_type varchar2(30);
    begin
        if p_server_code is null then
            return null;
        end if;
        select max(server_type) into l_type from xxfnd_servers where server_code = p_server_code;
        if l_type is null or l_type not in ('OBJECT_STORAGE', 'SHAREPOINT', 'UCM') then
            raise_application_error(-20334, 'Server ' || p_server_code
                || ' is not a storage server (OCI Object Storage, SharePoint or UCM).');
        end if;
        return l_type;
    end storage_server_type;

    procedure put_storage_row(p_app in varchar2, p_category in varchar2, p_type in varchar2, p_server in varchar2,
                              p_site in varchar2, p_library in varchar2, p_bucket in varchar2,
                              p_security_group in varchar2, p_account in varchar2, p_document_type in varchar2,
                              p_folder in varchar2) is
        l_id number;
    begin
        select max(storage_config_id) into l_id
          from xxfnd_storage_config
         where enabled_flag = 'Y'
           and nvl(application_code, '#') = nvl(p_app, '#')
           and nvl(category_code, '#') = nvl(p_category, '#');
        if l_id is null then
            if p_category is not null
               and coalesce(p_type, p_server, p_site, p_library, p_bucket, p_security_group, p_account,
                            p_document_type, p_folder) is null then
                return;   -- nothing to override
            end if;
            insert into xxfnd_storage_config (application_code, category_code, storage_type, server_code,
                                              sharepoint_site_id, sharepoint_drive_id, bucket_name, ucm_security_group,
                                              ucm_doc_account, ucm_doc_type, folder_path_template, enabled_flag)
            values (p_app, p_category, p_type, p_server, p_site, p_library, p_bucket, p_security_group, p_account,
                    p_document_type, p_folder, 'Y')
            returning storage_config_id into l_id;
            if p_app is null then
                -- COMMON (the instance): the screen's default-application trigger (16i, _SC) may have set the
                -- application in scope
                update xxfnd_storage_config set application_code = null
                 where storage_config_id = l_id and application_code is not null;
            end if;
        else
            update xxfnd_storage_config
               set storage_type         = p_type,
                   server_code          = p_server,
                   sharepoint_site_id   = p_site,
                   sharepoint_drive_id  = p_library,
                   bucket_name          = p_bucket,
                   ucm_security_group   = p_security_group,
                   ucm_doc_account      = p_account,
                   ucm_doc_type         = p_document_type,
                   folder_path_template = p_folder
             where storage_config_id = l_id;
        end if;
    end put_storage_row;

    procedure save_app_storage(p_application_code in varchar2,
                               p_server_code      in varchar2,
                               p_site             in varchar2 default null,
                               p_library          in varchar2 default null,
                               p_bucket           in varchar2 default null,
                               p_security_group   in varchar2 default null,
                               p_account          in varchar2 default null,
                               p_document_type    in varchar2 default null,
                               p_folder           in varchar2 default null) is
        l_app  varchar2(30) := storage_app(p_application_code);
        l_type varchar2(30) := nvl(storage_server_type(p_server_code), c_database);
    begin
        put_storage_row(l_app, null, l_type, p_server_code,
                        case when l_type = 'SHAREPOINT'     then p_site end,
                        case when l_type = 'SHAREPOINT'     then p_library end,
                        case when l_type = 'OBJECT_STORAGE' then p_bucket end,
                        case when l_type = 'UCM'            then p_security_group end,
                        case when l_type = 'UCM'            then p_account end,
                        case when l_type = 'UCM'            then p_document_type end,
                        case when l_type <> c_database      then p_folder end);
    end save_app_storage;

    procedure save_category_storage(p_application_code in varchar2,
                                    p_category_code    in varchar2,
                                    p_server_code      in varchar2,
                                    p_site             in varchar2 default null,
                                    p_library          in varchar2 default null,
                                    p_bucket           in varchar2 default null,
                                    p_security_group   in varchar2 default null,
                                    p_account          in varchar2 default null,
                                    p_document_type    in varchar2 default null,
                                    p_folder           in varchar2 default null) is
        l_app    varchar2(30) := storage_app(p_application_code);
        l_n      pls_integer;
        l_type   varchar2(30);     -- the row's own type (empty = as the application)
        l_eff    varchar2(30);     -- the type the category's files go to
        l_server varchar2(255);
    begin
        select count(*) into l_n from xxfnd_document_categories
         where category_code = p_category_code
           and (application_code = upper(p_application_code) or application_code is null);
        if l_n = 0 then
            raise_application_error(-20335, 'Category ' || p_category_code || ' is not used by application '
                || upper(p_application_code) || '.');
        end if;
        if upper(p_server_code) = c_database then
            l_type := c_database;
            l_eff  := c_database;
        elsif p_server_code is not null then
            l_server := p_server_code;
            l_type   := storage_server_type(p_server_code);
            l_eff    := l_type;
        else
            select max(s.server_type) into l_eff
              from xxfnd_storage_config d
              join xxfnd_servers s on s.server_code = d.server_code
             where d.enabled_flag = 'Y' and d.category_code is null and nvl(d.application_code, '#') = nvl(l_app, '#');
        end if;
        put_storage_row(l_app, p_category_code, l_type, l_server,
                        case when l_eff = 'SHAREPOINT'     then p_site end,
                        case when l_eff = 'SHAREPOINT'     then p_library end,
                        case when l_eff = 'OBJECT_STORAGE' then p_bucket end,
                        case when l_eff = 'UCM'            then p_security_group end,
                        case when l_eff = 'UCM'            then p_account end,
                        case when l_eff = 'UCM'            then p_document_type end,
                        case when nvl(l_eff, c_database) <> c_database then p_folder end);
    end save_category_storage;

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
        l_path := replace(l_path, '#CATEGORY#',      p_category);    -- release 86: the default folder's token
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
         where f.apex_app_alias = v('APP_ALIAS')
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
        l_stored := upload(p_cfg, p_entity, p_pk1, l_folder, p_file, p_filename, p_mime,
                                                  p_title, p_previous_external_id);

        if p_cfg.storage_type = c_database or p_cfg.storage_config_id is null then
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
        l_container varchar2(500);
    begin
        check_entity(p_entity_name);
        check_category_rules(p_category_code, p_document_date, p_expiry_date);
        get_temp_file(p_temp_file_name, l_blob, l_filename, l_mime);
        check_upload(p_page_id, p_category_code, l_filename, l_blob);
        l_cfg := resolve_storage(p_entity_name, p_category_code);

        l_stored := store_file(l_cfg, p_entity_name, p_pk1_value, p_pk2_value, p_pk3_value, p_pk4_value,
                               p_pk5_value, p_category_code, l_blob, l_filename, l_mime,
                               nvl(p_title, l_filename), null);

        -- release 86: the document keeps its server and library / bucket (SERVER_CODE, STORAGE_CONTAINER)
        l_container := storage_container(l_cfg);   -- a private function cannot be called in SQL (PLS-00231)
        insert into xxfnd_documents (category_code, datatype_code, version_number, storage_config_id,
                                     storage_type, external_document_id, external_version_id, external_url,
                                     file_name, mime_type, file_size_bytes, document_date, expiry_date,
                                     upload_status, server_code, storage_container)
        values (p_category_code, 'FILE', 1, l_cfg.storage_config_id, l_cfg.storage_type,
                l_stored.external_document_id, l_stored.external_version_id, l_stored.external_url,
                l_filename, l_mime, dbms_lob.getlength(l_blob), p_document_date, p_expiry_date, 'STORED',
                l_cfg.server_code, l_container)
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
        l_new      xxfnd_storage_config%rowtype;
        l_container varchar2(500);
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
        if l_old.storage_type = c_database then
            l_cfg := database_config;
        else
            -- release 86: the server and library / bucket the first version is in; the UCM metadata and the folder of
            -- its storage row, else of the setup that applies now
            l_cfg := document_location(l_old);
            l_new := resolve_storage(l_ad.entity_name, l_ad.category_code);
            l_cfg.ucm_security_group   := coalesce(l_cfg.ucm_security_group, l_new.ucm_security_group);
            l_cfg.ucm_doc_account      := coalesce(l_cfg.ucm_doc_account, l_new.ucm_doc_account);
            l_cfg.ucm_doc_type         := coalesce(l_cfg.ucm_doc_type, l_new.ucm_doc_type);
            l_cfg.folder_path_template := coalesce(l_cfg.folder_path_template, l_new.folder_path_template,
                                                   '/#CATEGORY#/#ENTITY_NAME#/#PK1_VALUE#');
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

        l_container := storage_container(l_cfg);   -- a private function cannot be called in SQL (PLS-00231)
        insert into xxfnd_documents (category_code, datatype_code, base_document_id, version_number,
                                     storage_config_id, storage_type, external_document_id, external_version_id,
                                     external_url, file_name, mime_type, file_size_bytes, document_date,
                                     expiry_date, upload_status, server_code, storage_container)
        values (l_old.category_code, 'FILE', nvl(l_old.base_document_id, l_old.document_id), l_old.version_number + 1,
                l_cfg.storage_config_id, l_cfg.storage_type, l_stored.external_document_id,
                l_stored.external_version_id, l_stored.external_url, l_filename, l_mime,
                dbms_lob.getlength(l_blob), p_document_date, p_expiry_date, 'STORED',
                l_cfg.server_code, l_container)
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

        l_blob := fetch_file(l_doc, l_newer = 0, l_ent, l_pk1);

        apex_http.download(
            p_blob         => l_blob,
            p_content_type => nvl(l_doc.mime_type, 'application/octet-stream'),
            p_filename     => l_doc.file_name,
            p_is_inline    => p_inline = 'Y');
    end download;

    function record_visible(p_entity_name in varchar2, p_pk1_value in varchar2) return varchar2 is
        l_ent xxfnd_document_entities%rowtype;
        l_n   pls_integer;
    begin
        select * into l_ent from xxfnd_document_entities where entity_name = upper(p_entity_name) and enabled_flag = 'Y';
        -- the entity's table and key come from the registry only; the row is read under the user's data security
        execute immediate 'select count(*) from ' || xxfnd_util_pkg.qualified(l_ent.table_name)
                       || ' where to_char(' || dbms_assert.simple_sql_name(l_ent.pk1_column) || ') = :k'
            into l_n using p_pk1_value;
        return case when l_n > 0 then 'Y' else 'N' end;
    exception
        when no_data_found then
            return 'N';
        when others then
            if sqlcode in (-942, -20130) then
                return 'N';   -- the table is not there or not shared with COMMON
            end if;
            raise;
    end record_visible;

    procedure assert_change(p_app_alias in varchar2, p_page_id in number, p_region_static_id in varchar2,
                            p_entity_name in varchar2, p_pk1_value in varchar2, p_action in varchar2,
                            p_attached_document_id in number default null) is
        l_n pls_integer := 1;
    begin
        if p_attached_document_id is not null then
            select count(*) into l_n from xxfnd_attached_documents
             where attached_document_id = p_attached_document_id
               and entity_name = upper(p_entity_name) and pk1_value = p_pk1_value and expiration_date is null;
        end if;
        if l_n = 0
           or record_visible(p_entity_name, p_pk1_value) = 'N'
           or block_permission(p_app_alias, p_page_id, p_region_static_id, upper(p_entity_name), upper(p_action)) = 'N' then
            raise_application_error(-20332, 'You are not allowed to change the documents of this record here.');
        end if;
    end assert_change;

    procedure download_checked(p_document_id in number, p_inline in varchar2 default 'N') is
        l_ok varchar2(1) := 'N';
    begin
        for a in (select ad.entity_name, ad.pk1_value
                    from xxfnd_attached_documents ad
                    join xxfnd_documents d on d.document_id = ad.document_id
                   where ad.document_id = p_document_id
                      or nvl(d.base_document_id, d.document_id) =
                         (select nvl(x.base_document_id, x.document_id) from xxfnd_documents x where x.document_id = p_document_id)) loop
            if record_visible(a.entity_name, a.pk1_value) = 'Y' then
                l_ok := 'Y';
                exit;
            end if;
        end loop;
        if l_ok = 'N' then
            raise_application_error(-20331, 'You are not allowed to open this document.');
        end if;
        download(p_document_id, p_inline);
    end download_checked;

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

    procedure save_entity_display_name(p_entity_name in varchar2, p_display_name in varchar2) is
    begin
        merge into xxfnd_document_entities_tl t
        using (select p_entity_name entity_name, 'en' language_code from dual) s
           on (t.entity_name = s.entity_name and t.language_code = s.language_code)
         when matched then update set t.user_entity_name = p_display_name
         when not matched then insert (entity_name, language_code, user_entity_name)
                               values (s.entity_name, 'en', p_display_name);
    end save_entity_display_name;

    ----------------------------------------------------------------------------
    -- Release 86 (part A): registration and moving documents between records
    ----------------------------------------------------------------------------
    procedure register_entity(p_application_code in varchar2,
                              p_entity_name      in varchar2,
                              p_table_name       in varchar2,
                              p_pk1_column       in varchar2,
                              p_display_name     in varchar2,
                              p_display_name_ar  in varchar2 default null,
                              p_pk2_column       in varchar2 default null) is
        l_code xxfnd_document_entities.application_code%type := xxfnd_application_pkg.setup_code(p_application_code);
        l_name xxfnd_document_entities.entity_name%type := upper(p_entity_name);
        l_n    pls_integer;
        l_row  xxfnd_document_entities.application_code%type;
    begin
        select count(*), max(application_code) into l_n, l_row from xxfnd_document_entities where entity_name = l_name;
        if l_n > 0 then
            xxfnd_application_pkg.assert_same_application('Document entity', l_name, l_row, p_application_code);
        else
            insert into xxfnd_document_entities (entity_name, application_code, table_name, pk1_column, pk2_column, enabled_flag)
            values (l_name, l_code, upper(p_table_name), upper(p_pk1_column), upper(p_pk2_column), 'Y');
        end if;
        merge into xxfnd_document_entities_tl t
        using (select l_name entity_name, 'en' lang, p_display_name name from dual
               union all
               select l_name, 'ar', p_display_name_ar from dual where p_display_name_ar is not null) s
           on (t.entity_name = s.entity_name and t.language_code = s.lang)
         when not matched then insert (entity_name, language_code, user_entity_name) values (s.entity_name, s.lang, s.name);
    end register_entity;

    procedure register_category(p_application_code      in varchar2,
                                p_category_code         in varchar2,
                                p_category_name         in varchar2,
                                p_category_name_ar      in varchar2 default null,
                                p_description           in varchar2 default null,
                                p_default_datatype_code in varchar2 default 'FILE',
                                p_has_expiry_flag       in varchar2 default 'N',
                                p_max_age_days          in number   default null,
                                p_max_file_size_mb      in number   default null,
                                p_allowed_file_types    in varchar2 default null) is
        l_code xxfnd_document_categories.application_code%type := xxfnd_application_pkg.setup_code(p_application_code);
        l_cat  xxfnd_document_categories.category_code%type := upper(p_category_code);
        l_n    pls_integer;
        l_row  xxfnd_document_categories.application_code%type;
        -- NORMALISE_TYPES is private to the package body, so it cannot be called inside SQL (PLS-00231)
        l_types xxfnd_document_categories.allowed_file_types%type := normalise_types(p_allowed_file_types);
    begin
        select count(*), max(application_code) into l_n, l_row from xxfnd_document_categories where category_code = l_cat;
        if l_n > 0 then
            xxfnd_application_pkg.assert_same_application('Document category', l_cat, l_row, p_application_code);
        else
            -- the English name is the category's own; other languages in XXFND_DOCUMENT_CATEGORIES_TL
            insert into xxfnd_document_categories (category_code, application_code, category_name, description,
                                                   default_datatype_code, has_expiry_flag, max_age_days,
                                                   max_file_size_mb, allowed_file_types)
            values (l_cat, l_code, p_category_name, p_description, upper(nvl(p_default_datatype_code, 'FILE')),
                    nvl(p_has_expiry_flag, 'N'), p_max_age_days, p_max_file_size_mb, l_types);
        end if;
        if p_category_name_ar is not null then
            merge into xxfnd_document_categories_tl t
            using (select l_cat category_code, 'ar' language_code from dual) s
               on (t.category_code = s.category_code and t.language_code = s.language_code)
             when not matched then insert (category_code, language_code, category_name) values (l_cat, 'ar', p_category_name_ar);
        end if;
    end register_category;

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
                                       p_display_sequence    in number   default 10) is
        l_code  xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);
        l_fn    xxfnd_attachment_functions.function_code%type := upper(p_function_code);
        l_alias xxfnd_applications.apex_app_alias%type;
        l_n     pls_integer;
        l_row   xxfnd_attachment_functions.application_code%type;
        l_other xxfnd_attachment_functions.function_code%type;
    begin
        select nvl(apex_app_alias, application_code) into l_alias from xxfnd_applications where application_code = l_code;
        select count(*) into l_n from xxfnd_document_entities where entity_name = upper(p_entity_name);
        if l_n = 0 then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Document entity', upper(p_entity_name)));
        end if;
        select count(*), max(application_code) into l_n, l_row from xxfnd_attachment_functions where function_code = l_fn;
        if l_n > 0 then
            xxfnd_application_pkg.assert_same_application('Attachment page', l_fn, l_row, l_code);
        else
            select max(function_code) into l_other from xxfnd_attachment_functions
             where upper(apex_app_alias) = upper(l_alias) and apex_page_id = p_page_id;
            if l_other is not null then
                xxfnd_error_pkg.raise_error('XXFND_REG_PAGE_TAKEN', apex_t_varchar2(l_alias, to_char(p_page_id), l_other));
            end if;
            insert into xxfnd_attachment_functions (function_code, application_code, function_name, apex_app_alias,
                                                    apex_page_id, enabled_flag)
            values (l_fn, xxfnd_application_pkg.setup_code(l_code), p_function_name, l_alias, p_page_id, 'Y');
        end if;
        merge into xxfnd_attachment_blocks t
        using (select l_fn function_code, upper(p_block_code) block_code from dual) s
           on (t.function_code = s.function_code and t.block_code = s.block_code)
         when not matched then insert (function_code, block_code, region_static_id, block_name, display_sequence)
                               values (s.function_code, s.block_code, p_region_static_id, p_block_name, p_display_sequence);
        merge into xxfnd_attachment_blk_entities t
        using (select l_fn function_code, upper(p_block_code) block_code, upper(p_entity_name) entity_name from dual) s
           on (t.function_code = s.function_code and t.block_code = s.block_code and t.entity_name = s.entity_name)
         when not matched then insert (function_code, block_code, entity_name, pk1_page_item, insert_allowed_flag,
                                       update_allowed_flag, delete_allowed_flag, display_sequence)
                               values (s.function_code, s.block_code, s.entity_name, upper(p_pk1_page_item),
                                       nvl(p_insert_allowed_flag, 'Y'), nvl(p_update_allowed_flag, 'Y'),
                                       nvl(p_delete_allowed_flag, 'N'), p_display_sequence);
    end register_attachment_page;

    procedure move_documents(p_entity_name in varchar2, p_from_pk1 in varchar2, p_to_pk1 in varchar2) is
        l_entity xxfnd_attached_documents.entity_name%type := upper(p_entity_name);
        l_after  number;
    begin
        if p_from_pk1 is null or p_to_pk1 is null or p_from_pk1 = p_to_pk1 then
            return;
        end if;
        -- the versions of a document hang off its first version (BASE_DOCUMENT_ID): moving the link moves them all
        select nvl(max(seq_num), 0) into l_after
          from xxfnd_attached_documents
         where entity_name = l_entity and pk1_value = p_to_pk1;
        update xxfnd_attached_documents
           set pk1_value = p_to_pk1,
               seq_num   = seq_num + l_after
         where entity_name = l_entity
           and pk1_value   = p_from_pk1;
    end move_documents;

    -- release 88 (C8, C9)
    procedure unregister_entity(p_application_code in varchar2, p_entity_name in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Document entity', 'XXFND_DOCUMENT_ENTITIES', apex_t_varchar2('ENTITY_NAME'),
            apex_t_varchar2(upper(trim(p_entity_name))));
    end unregister_entity;

    procedure unregister_category(p_application_code in varchar2, p_category_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Document category', 'XXFND_DOCUMENT_CATEGORIES', apex_t_varchar2('CATEGORY_CODE'),
            apex_t_varchar2(upper(trim(p_category_code))));
    end unregister_category;

    procedure unregister_attachment_page(p_application_code in varchar2, p_function_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Attachment page', 'XXFND_ATTACHMENT_FUNCTIONS', apex_t_varchar2('FUNCTION_CODE'),
            apex_t_varchar2(upper(trim(p_function_code))));
    end unregister_attachment_page;

    procedure unregister_application(p_application_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Storage settings', 'XXFND_STORAGE_CONFIG');
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Attachment pages', 'XXFND_ATTACHMENT_FUNCTIONS');
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Document categories', 'XXFND_DOCUMENT_CATEGORIES');
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Document entities', 'XXFND_DOCUMENT_ENTITIES');
    end unregister_application;

end xxfnd_attach_pkg;
/
