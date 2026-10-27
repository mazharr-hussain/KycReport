
create or replace package body xxfnd_integration_pkg as

    g_sync_running boolean := false;

    procedure upsert_fusion_worker(p_worker in json_object_t) is
        l_person_id   number        := p_worker.get_number('PersonId');
        l_number      varchar2(30)  := p_worker.get_string('PersonNumber');
        l_name        varchar2(240) := p_worker.get_string('DisplayName');
        l_email       varchar2(320) := lower(p_worker.get_string('WorkEmail'));
        l_dept        varchar2(240);
        l_job         varchar2(240);
        l_assignments json_array_t;
        l_asg         json_object_t;
    begin
        if l_person_id is null or l_email is null then
            return; -- a worker without a work email cannot sign in; skip
        end if;
        if p_worker.has('assignments') then
            l_assignments := p_worker.get_array('assignments');
            if l_assignments.get_size > 0 then
                l_asg  := treat(l_assignments.get(0) as json_object_t);
                l_dept := l_asg.get_string('DepartmentName');
                l_job  := l_asg.get_string('JobName');
            end if;
        end if;

        -- A LOCAL record created before the person existed in Fusion is adopted,
        -- not duplicated (the email and user name are unique).
        update xxhr_employees
           set source_type = 'FUSION', fusion_person_id = l_person_id
         where source_type = 'LOCAL'
           and fusion_person_id is null
           and (email_address = l_email or user_name = upper(l_email));

        merge into xxhr_employees e
        using (select l_person_id person_id from dual) s
           on (e.fusion_person_id = s.person_id)
         when matched then update set
              e.fusion_person_number = l_number,
              e.full_name            = nvl(l_name, e.full_name),
              e.email_address        = l_email,
              e.department_name      = l_dept,
              e.job_title            = l_job,
              e.enabled_flag         = 'Y',
              e.last_sync_date       = systimestamp
         when not matched then insert
              (source_type, fusion_person_id, fusion_person_number, user_name, full_name,
               email_address, department_name, job_title, last_sync_date)
              values
              ('FUSION', l_person_id, l_number, upper(l_email), nvl(l_name, l_email),
               l_email, l_dept, l_job, systimestamp);
    end upsert_fusion_worker;

    procedure sync_user_names(p_base_url             in varchar2,
                              p_credential_static_id in varchar2,
                              p_page_size            in pls_integer default 200) is
        l_offset   pls_integer := 0;
        l_response clob;
        l_doc      json_object_t;
        l_items    json_array_t;
        l_item     json_object_t;
        l_has_more boolean := true;
    begin
        while l_has_more loop
            l_response := apex_web_service.make_rest_request(
                              p_url                  => rtrim(p_base_url, '/')
                                                        || '/hcmRestApi/resources/11.13.18.05/userAccounts'
                                                        || '?onlyData=true&limit=' || p_page_size || '&offset=' || l_offset
                                                        || '&fields=Username,PersonId,UserId',
                              p_http_method          => 'GET',
                              p_credential_static_id => p_credential_static_id);
            if apex_web_service.g_status_code <> 200 then
                -- user names stay as they are; the worker sync itself is not failed
                apex_debug.warn('sync_user_names: HTTP %0 from userAccounts', apex_web_service.g_status_code);
                return;
            end if;
            l_doc   := json_object_t.parse(l_response);
            l_items := l_doc.get_array('items');
            for i in 0 .. l_items.get_size - 1 loop
                l_item := treat(l_items.get(i) as json_object_t);
                if l_item.get_number('PersonId') is not null and trim(l_item.get_string('Username')) is not null then
                    -- trigger XXHR_EMPLOYEES_RENAME moves the references (rename_user)
                    update xxhr_employees
                       set user_name      = upper(trim(l_item.get_string('Username'))),
                           fusion_user_id = nvl(to_char(l_item.get_number('UserId')), fusion_user_id)
                     where fusion_person_id = l_item.get_number('PersonId')
                       and (user_name <> upper(trim(l_item.get_string('Username')))
                            or nvl(fusion_user_id, '#') <> nvl(to_char(l_item.get_number('UserId')), nvl(fusion_user_id, '#')));
                end if;
            end loop;
            l_has_more := nvl(l_doc.get_boolean('hasMore'), false);
            l_offset   := l_offset + p_page_size;
            commit;
        end loop;
    end sync_user_names;

    procedure sync_from_fusion(p_base_url              in varchar2,
                               p_credential_static_id  in varchar2,
                               p_page_size             in pls_integer default 200) is
        l_offset   pls_integer := 0;
        l_response clob;
        l_doc      json_object_t;
        l_items    json_array_t;
        l_has_more boolean := true;
        l_url      varchar2(4000);
        l_run_ts   timestamp := systimestamp;
    begin
        g_sync_running := true;
        while l_has_more loop
            l_url := rtrim(p_base_url, '/')
                  || '/hcmRestApi/resources/11.13.18.05/publicWorkers'
                  || '?onlyData=true&limit=' || p_page_size || '&offset=' || l_offset
                  || '&fields=PersonId,PersonNumber,DisplayName,WorkEmail;assignments:DepartmentName,JobName';
            l_response := apex_web_service.make_rest_request(
                              p_url                  => l_url,
                              p_http_method          => 'GET',
                              p_credential_static_id => p_credential_static_id);
            if apex_web_service.g_status_code <> 200 then
                raise_application_error(-20110, 'Fusion HCM sync failed with HTTP '
                    || apex_web_service.g_status_code || ': ' || dbms_lob.substr(l_response, 500, 1));
            end if;
            l_doc   := json_object_t.parse(l_response);
            l_items := l_doc.get_array('items');
            for i in 0 .. l_items.get_size - 1 loop
                upsert_fusion_worker(treat(l_items.get(i) as json_object_t));
            end loop;
            l_has_more := nvl(l_doc.get_boolean('hasMore'), false);
            l_offset   := l_offset + p_page_size;
            commit;
        end loop;

        -- user names = the Fusion / identity-domain user names (the e-mail stays for workers without an account)
        sync_user_names(p_base_url, p_credential_static_id, p_page_size);

        -- Workers no longer returned by Fusion (terminated) are disabled, not deleted.
        update xxhr_employees e
           set e.enabled_flag = 'N'
         where e.source_type = 'FUSION'
           and e.enabled_flag = 'Y'
           and (e.last_sync_date is null or e.last_sync_date < l_run_ts);
        commit;
        g_sync_running := false;
    exception
        when others then
            g_sync_running := false;
            raise;
    end sync_from_fusion;

    function sync_running return boolean is
    begin
        return g_sync_running;
    end sync_running;

    ---------------------------------------------------------------- release 83: servers, calls, log
    procedure assert_manage is
    begin
        if not xxfnd_privilege_pkg.has_privilege('INTEGRATIONS', 'MANAGE') then
            raise_application_error(-20313, 'You are not allowed to do this (Integrations - Manage).');
        end if;
    end assert_manage;

    -- a readable reason for a request that did not reach the server (shown on the Servers screens and in the log)
    function failure_text(p_sqlcode in number, p_sqlerrm in varchar2) return varchar2 is
    begin
        return case when p_sqlcode in (-29273, -29024, -24247, -12535, -12541)
                    then 'The server could not be reached: check its URL and the network access (ACL) of the database.'
                    else p_sqlerrm end;
    end failure_text;

    function server(p_static_id in varchar2) return t_server is
        l_srv t_server;
    begin
        -- release 86: the server the COMMON administrator defined (XXFND_SERVERS_V holds the URL and credential rule)
        for s in (select server_code, server_name, base_url, credential_static_id, server_type, oauth_token_url,
                         oci_region, oci_namespace
                    from xxfnd_servers_v
                   where server_code = p_static_id) loop
            l_srv.static_id            := s.server_code;
            l_srv.server_name          := s.server_name;
            l_srv.base_url             := s.base_url;
            l_srv.credential_static_id := s.credential_static_id;
            l_srv.server_type          := s.server_type;
            l_srv.oauth_token_url      := s.oauth_token_url;
            l_srv.oci_region           := s.oci_region;
            l_srv.oci_namespace        := s.oci_namespace;
            return l_srv;
        end loop;
        -- an APEX Remote Server not defined as a server yet
        for r in (select remote_server_static_id, remote_server_name, base_url
                    from apex_workspace_remote_servers
                   where remote_server_static_id = p_static_id) loop
            l_srv.static_id   := r.remote_server_static_id;
            l_srv.server_name := r.remote_server_name;
            l_srv.base_url    := r.base_url;
        end loop;
        if l_srv.static_id is not null then
            -- its Web Credential: of a COMMON REST Data Source on it, else <static ID>_CREDENTIALS
            select coalesce(
                     (select max(m.credential_static_id) from apex_appl_web_src_modules m
                       where m.remote_server_static_id = p_static_id and m.credential_static_id is not null
                         and m.application_id = (select apex_application_id from xxfnd_applications
                                                  where application_code = 'COMMON')),
                     (select max(c.static_id) from apex_workspace_credentials c
                       where c.static_id = p_static_id || '_CREDENTIALS'))
              into l_srv.credential_static_id
              from dual;
            return l_srv;
        end if;
        raise_application_error(-20301, 'Server ' || p_static_id
            || ' is not set up: the COMMON administrator defines it on the Servers screen (an APEX Remote Server of the'
            || ' workspace and its Web Credential).');
    end server;

    ---------------------------------------------------------------- release 86: servers and purposes screens
    procedure save_server(p_server_code          in varchar2,
                          p_server_name          in varchar2,
                          p_server_type          in varchar2,
                          p_credential_static_id in varchar2 default null,
                          p_oauth_token_url      in varchar2 default null,
                          p_oci_region           in varchar2 default null,
                          p_oci_namespace        in varchar2 default null,
                          p_enabled_flag         in varchar2 default 'Y',
                          p_description          in varchar2 default null,
                          p_base_url             in varchar2 default null,
                          -- release 93: FUSION - the workspace's Fusion integration application
                          p_source_application_id in number  default null,
                          p_auth_server_code     in varchar2 default null) is
        l_type varchar2(30) := upper(p_server_type);
    begin
        if l_type is null or l_type not in ('OBJECT_STORAGE', 'SHAREPOINT', 'UCM', 'FUSION', 'REST', 'OUTLOOK') then
            raise_application_error(-20341, 'Choose the server type: OCI Object Storage, SharePoint, UCM, Fusion, REST or Outlook.');
        end if;
        merge into xxfnd_servers t
        using (select p_server_code server_code from dual) s
           on (t.server_code = s.server_code)
         when matched then update set
              t.server_name          = p_server_name,
              t.server_type          = l_type,
              t.credential_static_id = p_credential_static_id,
              -- release 109: a value not given keeps the stored one (older servers); new ones come from APEX
              t.oauth_token_url      = case when l_type in ('SHAREPOINT', 'OUTLOOK') then nvl(p_oauth_token_url, t.oauth_token_url) end,
              t.oci_region           = case when l_type = 'OBJECT_STORAGE' then nvl(p_oci_region, t.oci_region) end,
              t.oci_namespace        = case when l_type = 'OBJECT_STORAGE' then nvl(p_oci_namespace, t.oci_namespace) end,
              t.auth_server_code     = case when l_type in ('SHAREPOINT', 'OUTLOOK') then p_auth_server_code end,
              t.enabled_flag         = nvl(p_enabled_flag, 'Y'),
              t.description          = p_description,
              t.base_url             = nvl(p_base_url, t.base_url),
              t.source_application_id = case when l_type = 'FUSION' then p_source_application_id end
         when not matched then insert
              (server_code, server_name, server_type, credential_static_id, oauth_token_url, oci_region, oci_namespace,
               enabled_flag, description, base_url, source_application_id, auth_server_code)
              values
              (s.server_code, p_server_name, l_type, p_credential_static_id,
               case when l_type in ('SHAREPOINT', 'OUTLOOK') then p_oauth_token_url end,
               case when l_type = 'OBJECT_STORAGE' then p_oci_region end,
               case when l_type = 'OBJECT_STORAGE' then p_oci_namespace end,
               nvl(p_enabled_flag, 'Y'), p_description, p_base_url,
               case when l_type = 'FUSION' then p_source_application_id end,
               case when l_type in ('SHAREPOINT', 'OUTLOOK') then p_auth_server_code end);
    end save_server;

    procedure delete_server(p_server_code in varchar2) is
        e_child exception;
        pragma exception_init(e_child, -2292);
    begin
        -- the storage rules (XXFND_STORAGE_CONFIG_FK4) and purposes (XXFND_INT_PURPOSES_FK2) refer to their server
        delete from xxfnd_servers where server_code = p_server_code;
    exception
        when e_child then
            raise_application_error(-20342, 'Server ' || p_server_code
                || ' is used by document storage or an integration purpose: disable it instead.');
    end delete_server;

    procedure save_purpose(p_purpose_code          in varchar2,
                           p_purpose_name          in varchar2,
                           p_application_code      in varchar2,
                           p_capture_method        in varchar2,
                           p_server_code           in varchar2,
                           p_rest_source_static_id in varchar2,
                           p_new                   in varchar2 default 'N',
                           p_catalog_service_id    in number   default null) is
    begin
        if p_new = 'Y' then
            begin
                insert into xxfnd_integration_purposes (purpose_code, purpose_name, application_code, capture_method,
                                                        server_code, rest_source_static_id, catalog_service_id)
                values (upper(p_purpose_code), p_purpose_name, p_application_code, p_capture_method,
                        p_server_code, p_rest_source_static_id, p_catalog_service_id);
            exception
                when dup_val_on_index then
                    raise_application_error(-20343, 'Purpose ' || upper(p_purpose_code) || ' already exists.');
            end;
        else
            update xxfnd_integration_purposes
               set purpose_name          = p_purpose_name,
                   application_code      = p_application_code,
                   capture_method        = p_capture_method,
                   server_code           = p_server_code,
                   rest_source_static_id = p_rest_source_static_id,
                   catalog_service_id    = p_catalog_service_id
             where purpose_code = p_purpose_code;
        end if;
    end save_purpose;

    procedure delete_purpose(p_purpose_code in varchar2) is
        e_child exception;
        pragma exception_init(e_child, -2292);
    begin
        delete from xxfnd_integration_purposes where purpose_code = p_purpose_code;
    exception
        when e_child then
            raise_application_error(-20344, 'Purpose ' || p_purpose_code || ' has logged calls: it cannot be deleted.');
    end delete_purpose;

    function log_start(p_server_static_id in varchar2, p_http_method in varchar2, p_url in varchar2,
                       p_entity_name in varchar2 default null, p_pk1_value in varchar2 default null,
                       p_purpose_code in varchar2 default null) return number is
        pragma autonomous_transaction;
        l_id number;
    begin
        insert into xxfnd_integration_calls (purpose_code, server_static_id, http_method, request_url, retryable_flag,
                                             entity_name, pk1_value, called_by)
        values (p_purpose_code, p_server_static_id, p_http_method, substr(p_url, 1, 4000), 'N',
                p_entity_name, p_pk1_value, xxfnd_util_pkg.current_user)
        returning call_id into l_id;
        commit;
        return l_id;
    end log_start;

    procedure log_end(p_call_id in number, p_http_status in number, p_error in varchar2 default null) is
        pragma autonomous_transaction;
        l_log_id number;
    begin
        select max(id) into l_log_id from apex_webservice_log;   -- the request APEX just logged (this session)
        update xxfnd_integration_calls
           set http_status       = p_http_status,
               status_code       = case when p_error is null and p_http_status between 200 and 299 then 'SUCCESS' else 'FAILED' end,
               error_message     = substr(p_error, 1, 4000),
               webservice_log_id = l_log_id
         where call_id = p_call_id;
        commit;
    end log_end;

    function do_call(p_purpose_code in varchar2, p_http_method in varchar2, p_path in varchar2, p_query in varchar2,
                     p_body in clob, p_entity_name in varchar2, p_pk1_value in varchar2,
                     p_retry_of in number) return clob is
        l_source  varchar2(255);
        l_url     varchar2(4000);
        l_cred    varchar2(255);
        l_server  varchar2(255);
        l_service number;
        l_srv     t_server;
        l_call_id number;
        l_resp    clob;
        procedure log_row is
            pragma autonomous_transaction;
        begin
            insert into xxfnd_integration_calls (purpose_code, server_static_id, rest_source_static_id, http_method,
                                                 request_url, request_path, request_query, request_body, entity_name,
                                                 pk1_value, retry_of_call_id, called_by)
            values (p_purpose_code, l_server, l_source, upper(p_http_method), substr(l_url, 1, 4000), p_path, p_query,
                    p_body, p_entity_name, p_pk1_value, p_retry_of, xxfnd_util_pkg.current_user)
            returning call_id into l_call_id;
            commit;
        end log_row;
    begin
        select max(rest_source_static_id), max(server_code), max(catalog_service_id)
          into l_source, l_server, l_service
          from xxfnd_integration_purposes where purpose_code = p_purpose_code;
        if l_service is not null then
            -- release 110: the endpoint of the REST Source Catalog service, on the purpose's server
            select max(cs.url_endpoint), max(c.credential_static_id)
              into l_url, l_cred
              from apex_rest_catalog_services cs
              left join apex_rest_catalogs c on c.catalog_id = cs.catalog_id
             where cs.service_id = l_service;
            if l_url is null then
                raise_application_error(-20312, 'Catalog service ' || l_service || ' of purpose ' || p_purpose_code
                    || ' is not in the REST Source Catalogs.');
            end if;
            if l_server is not null then
                l_srv  := server(l_server);
                l_url  := rtrim(l_srv.base_url, '/') || '/' || ltrim(regexp_replace(l_url, '^https?://[^/]+', ''), '/');
                l_cred := nvl(l_srv.credential_static_id, l_cred);
            end if;
            l_source := null;
        else
            if l_source is null then
                raise_application_error(-20312, 'Purpose ' || p_purpose_code
                    || ' has no REST Source Catalog service or REST Data Source.');
            end if;
            select max(m.remote_server_static_id),
                   max(rtrim(s.base_url, '/') || '/' || ltrim(m.url_endpoint, '/')),
                   max(m.credential_static_id)
              into l_server, l_url, l_cred
              from apex_appl_web_src_modules m
              left join apex_workspace_remote_servers s on s.remote_server_static_id = m.remote_server_static_id
             where m.module_static_id = l_source
               and m.application_id = (select apex_application_id from xxfnd_applications where application_code = 'COMMON');
            if l_url is null then
                raise_application_error(-20312, 'REST Data Source ' || l_source || ' is not in the COMMON application.');
            end if;
        end if;
        l_url := rtrim(l_url, '/') || case when p_path is not null then '/' || ltrim(p_path, '/') end
              || case when p_query is not null then '?' || ltrim(p_query, '?') end;
        log_row;
        begin
            l_resp := apex_web_service.make_rest_request(p_url                  => l_url,
                                                         p_http_method          => upper(p_http_method),
                                                         p_body                 => p_body,
                                                         p_credential_static_id => l_cred);
        exception
            when others then
                log_end(l_call_id, null, failure_text(sqlcode, sqlerrm));
                raise;
        end;
        if apex_web_service.g_status_code not between 200 and 299 then
            log_end(l_call_id, apex_web_service.g_status_code, 'HTTP ' || apex_web_service.g_status_code || ': '
                    || dbms_lob.substr(l_resp, 500, 1));
            raise_application_error(-20311, p_purpose_code || ' call failed (HTTP ' || apex_web_service.g_status_code || ').');
        end if;
        log_end(l_call_id, apex_web_service.g_status_code);
        return l_resp;
    end do_call;

    function call(p_purpose_code in varchar2,
                  p_http_method  in varchar2 default 'GET',
                  p_path         in varchar2 default null,
                  p_query        in varchar2 default null,
                  p_body         in clob     default null,
                  p_entity_name  in varchar2 default null,
                  p_pk1_value    in varchar2 default null) return clob is
    begin
        return do_call(p_purpose_code, p_http_method, p_path, p_query, p_body, p_entity_name, p_pk1_value, null);
    end call;

    procedure retry(p_call_id in number) is
        l_call xxfnd_integration_calls%rowtype;
        l_resp clob;
    begin
        assert_manage;
        select * into l_call from xxfnd_integration_calls where call_id = p_call_id;
        if l_call.retryable_flag = 'N' or l_call.purpose_code is null then
            raise_application_error(-20314, 'This call was not made through the COMMON call procedure: repeat the action on its own screen.');
        end if;
        if l_call.status_code <> 'FAILED' then
            raise_application_error(-20315, 'Only a failed call can be retried.');
        end if;
        l_resp := do_call(l_call.purpose_code, l_call.http_method, l_call.request_path, l_call.request_query,
                          l_call.request_body, l_call.entity_name, l_call.pk1_value, p_call_id);
    end retry;

    function can_retry(p_call_id in number) return varchar2 is
        l_n number;
    begin
        select count(*) into l_n from xxfnd_integration_calls
         where call_id = p_call_id and status_code = 'FAILED' and retryable_flag = 'Y' and purpose_code is not null;
        return case when l_n > 0 then 'Y' else 'N' end;
    end can_retry;

    function test_connection(p_server_static_id in varchar2) return varchar2 is
        pragma autonomous_transaction;
        l_srv    t_server;
        l_resp   clob;
        l_status number;
        l_result varchar2(20);
        l_msg    varchar2(4000);
    begin
        assert_manage;
        l_srv := server(p_server_static_id);
        begin
            l_resp := apex_web_service.make_rest_request(p_url                  => l_srv.base_url,
                                                         p_http_method          => 'GET',
                                                         p_credential_static_id => l_srv.credential_static_id);
            l_status := apex_web_service.g_status_code;
            l_result := case when l_status < 500 then 'REACHABLE' else 'FAILED' end;
            l_msg    := 'HTTP ' || l_status;
        exception
            when others then
                l_result := 'FAILED';
                l_msg    := substr(failure_text(sqlcode, sqlerrm), 1, 4000);
        end;
        merge into xxfnd_server_tests t
        using (select p_server_static_id sid from dual) s on (t.server_static_id = s.sid)
         when matched then update set t.tested_date = systimestamp, t.tested_by = xxfnd_util_pkg.current_user,
                                      t.http_status = l_status, t.result_code = l_result, t.result_message = l_msg
         when not matched then insert (server_static_id, tested_date, tested_by, http_status, result_code, result_message)
                               values (s.sid, systimestamp, xxfnd_util_pkg.current_user, l_status, l_result, l_msg);
        commit;
        return case when l_result = 'REACHABLE' then 'Reachable (' || l_msg || ').' else 'Not reachable. ' || l_msg end;
    end test_connection;

    procedure sync_hcm is
        l_source varchar2(255);
        l_srv    t_server;
    begin
        select max(rest_source_static_id) into l_source from xxfnd_integration_purposes
         where purpose_code = 'HCM_SYNC' and approval_status = 'APPROVED';
        if l_source is null then
            return;
        end if;
        begin
            l_srv := server('FUSION');
        exception
            when others then
                return;   -- the workspace administrator has not set up the FUSION server yet
        end;
        if l_srv.base_url is null or l_srv.credential_static_id is null then
            return;
        end if;
        sync_from_fusion(l_srv.base_url, l_srv.credential_static_id);
    end sync_hcm;

    ---------------------------------------------------------------- release 86 (part A): registration
    procedure register_purpose(p_application_code      in varchar2,
                               p_purpose_code          in varchar2,
                               p_purpose_name          in varchar2,
                               p_capture_method        in varchar2 default 'MANUAL',
                               p_rest_source_static_id in varchar2 default null) is
        l_code xxfnd_integration_purposes.application_code%type := xxfnd_application_pkg.setup_code(p_application_code);
        l_key  xxfnd_integration_purposes.purpose_code%type := upper(p_purpose_code);
        l_n    pls_integer;
        l_row  xxfnd_integration_purposes.application_code%type;
    begin
        select count(*), max(application_code) into l_n, l_row from xxfnd_integration_purposes where purpose_code = l_key;
        if l_n > 0 then
            xxfnd_application_pkg.assert_same_application('Integration purpose', l_key, l_row, p_application_code);
            return;
        end if;
        -- APPROVED from a script; the maker-checker trigger makes it PENDING_APPROVAL in an APEX session
        insert into xxfnd_integration_purposes (purpose_code, application_code, purpose_name, capture_method,
                                                rest_source_static_id, approval_status)
        values (l_key, l_code, p_purpose_name, upper(nvl(p_capture_method, 'MANUAL')), p_rest_source_static_id, 'APPROVED');
    end register_purpose;

    -- release 88 (C8, C9)
    procedure unregister_purpose(p_application_code in varchar2, p_purpose_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Integration purpose', 'XXFND_INTEGRATION_PURPOSES',
            apex_t_varchar2('PURPOSE_CODE'), apex_t_varchar2(upper(trim(p_purpose_code))));
    end unregister_purpose;

    procedure unregister_application(p_application_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Integration purposes', 'XXFND_INTEGRATION_PURPOSES');
    end unregister_application;

end xxfnd_integration_pkg;
/
