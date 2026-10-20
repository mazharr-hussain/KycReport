
-- release 86: the servers with their usage, effective URL and Web Credential, health and state (Servers screen,
-- storage of the applications, purposes)
create or replace view xxfnd_servers_v as
select q.server_code, q.server_name, q.server_type, q.server_type_name, q.usage, q.base_url, q.remote_server_flag,
       q.source_application_id, q.source_application, q.source_remote_server, q.credential_static_id, q.oauth_token_url, q.oci_region, q.oci_namespace, q.enabled_flag, q.description,
       q.last_call, q.last_error, q.last_test, q.missing,
       case when q.enabled_flag = 'N' then 'DISABLED'
            when q.missing is not null then 'INCOMPLETE'
            when q.last_test like 'FAILED%' then 'FAILED'
            else 'OK' end                                                   as status,
       case when q.enabled_flag = 'N' then 'Disabled'
            when q.missing is not null then 'Incomplete: needs ' || q.missing
            when q.last_test like 'FAILED%' then 'Last Test Connection failed'
            else 'OK' end                                                   as status_text
  from (select s.server_code, s.server_name, s.server_type,
               nvl((select max(v.meaning) from xxfnd_lookup_values v
                     where v.lookup_type = 'SERVER_TYPE' and v.lookup_code = s.server_type),
                   initcap(replace(s.server_type, '_', ' ')))              as server_type_name,
               case when s.server_type in ('OBJECT_STORAGE', 'SHAREPOINT', 'UCM') then 'STORAGE'
                    else 'INTEGRATION' end                                 as usage,
               coalesce(f.base_url, r.base_url, s.base_url,
                        case when s.server_type = 'OBJECT_STORAGE' and s.oci_region is not null
                             then 'https://objectstorage.' || s.oci_region || '.oraclecloud.com' end) as base_url,
               nvl2(coalesce(f.remote_server_static_id, r.remote_server_static_id), 'Y', 'N') as remote_server_flag,
               s.source_application_id,
               (select max(a.application_name || ' (' || a.application_id || ')') from apex_applications a
                 where a.application_id = s.source_application_id)          as source_application,
               f.remote_server_static_id                                    as source_remote_server,
               coalesce(f.credential_static_id, s.credential_static_id,
                        (select max(m.credential_static_id) from apex_appl_web_src_modules m
                          where m.remote_server_static_id = s.server_code and m.credential_static_id is not null
                            and m.application_id = (select a.apex_application_id from xxfnd_applications a
                                                     where a.application_code = 'COMMON')),
                        (select max(c.static_id) from apex_workspace_credentials c
                          where c.static_id = s.server_code || '_CREDENTIALS')) as credential_static_id,
               s.oauth_token_url, s.oci_region, s.oci_namespace, s.enabled_flag, s.description,
               (select max(c.called_date) from xxfnd_integration_calls c
                 where c.server_static_id = s.server_code)                 as last_call,
               (select max(c.called_date) from xxfnd_integration_calls c
                 where c.server_static_id = s.server_code and c.status_code = 'FAILED') as last_error,
               (select max(t.result_code || ' ' || to_char(t.tested_date, 'DD-Mon-YYYY HH24:MI'))
                  from xxfnd_server_tests t where t.server_static_id = s.server_code) as last_test,
               rtrim(case when coalesce(f.base_url, r.base_url, s.base_url,
                                        case when s.server_type = 'OBJECT_STORAGE' then s.oci_region end) is null
                          then 'its APEX Remote Server, ' end
                  || case when s.credential_static_id is null and f.credential_static_id is null
                           and not exists (select 1 from apex_appl_web_src_modules m
                                            where m.remote_server_static_id = s.server_code
                                              and m.credential_static_id is not null)
                           and not exists (select 1 from apex_workspace_credentials c
                                            where c.static_id = s.server_code || '_CREDENTIALS')
                          then 'a Web Credential, ' end
                  || case when s.server_type = 'OBJECT_STORAGE' and (s.oci_region is null or s.oci_namespace is null)
                          then 'the region and namespace, ' end
                  || case when s.server_type in ('SHAREPOINT', 'OUTLOOK') and s.oauth_token_url is null
                          then 'the OAuth token URL, ' end, ', ')           as missing
          from xxfnd_servers s
          left join apex_workspace_remote_servers r on r.remote_server_static_id = s.server_code
          -- release 93: the Remote Server and Web Credential of the source application's REST Data Sources
          left join (select m.application_id, max(m.remote_server_static_id) as remote_server_static_id,
                            max(w.base_url) as base_url, max(m.credential_static_id) as credential_static_id
                       from apex_appl_web_src_modules m
                       left join apex_workspace_remote_servers w on w.remote_server_static_id = m.remote_server_static_id
                      group by m.application_id) f on f.application_id = s.source_application_id) q;

comment on table xxfnd_servers_v is 'Release 86: the servers (XXFND_SERVERS) with their usage (STORAGE / INTEGRATION), effective URL (APEX Remote Server, else the copied URL, else the OCI region URL) and Web Credential, health, and STATUS: DISABLED, INCOMPLETE (MISSING says what), FAILED (last Test Connection) or OK.';
