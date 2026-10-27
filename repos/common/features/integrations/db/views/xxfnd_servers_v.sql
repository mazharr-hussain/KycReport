-- release 86: the servers with their usage, effective URL and Web Credential, health and state (Servers screen,
-- storage of the applications, purposes)
-- release 112: a server is linked to its APEX Remote Server (REMOTE_SERVER_CODE, empty = SERVER_CODE): the name and URL
-- are always read from it, so a change in Workspace Utilities shows here at once; the Fusion Integration Application
-- route (release 93) is gone
create or replace view xxfnd_servers_v as
select q.server_code, q.remote_server_code, q.remote_server_name, q.server_name, q.server_type, q.server_type_name,
       q.usage, q.base_url, q.remote_server_flag, q.credential_static_id, q.auth_server_code, q.oauth_token_url,
       q.oci_region, q.oci_namespace, q.enabled_flag, q.description,
       q.last_call, q.last_error, q.last_test, q.missing,
       case when q.enabled_flag = 'N' then 'DISABLED'
            when q.missing is not null then 'INCOMPLETE'
            when q.last_test like 'FAILED%' then 'FAILED'
            else 'OK' end                                                   as status,
       case when q.enabled_flag = 'N' then 'Disabled'
            when q.missing is not null then 'Incomplete: needs ' || q.missing
            when q.last_test like 'FAILED%' then 'Last Test Connection failed'
            else 'OK' end                                                   as status_text
  from (select s.server_code, s.rs as remote_server_code, r.remote_server_name,
               coalesce(r.remote_server_name, s.server_name)                as server_name,
               s.server_type,
               nvl((select max(v.meaning) from xxfnd_lookup_values v
                     where v.lookup_type = 'SERVER_TYPE' and v.lookup_code = s.server_type),
                   initcap(replace(s.server_type, '_', ' ')))              as server_type_name,
               case when s.server_type in ('OBJECT_STORAGE', 'SHAREPOINT', 'UCM') then 'STORAGE'
                    else 'INTEGRATION' end                                 as usage,
               coalesce(r.base_url, s.base_url,
                        case when s.server_type = 'OBJECT_STORAGE' and s.oci_region is not null
                             then 'https://objectstorage.' || s.oci_region || '.oraclecloud.com' end) as base_url,
               nvl2(r.remote_server_static_id, 'Y', 'N')                   as remote_server_flag,
               coalesce(s.credential_static_id,
                        (select max(m.credential_static_id) from apex_appl_web_src_modules m
                          where m.remote_server_static_id = s.rs and m.credential_static_id is not null
                            and m.application_id = (select a.apex_application_id from xxfnd_applications a
                                                     where a.application_code = 'COMMON')),
                        (select max(c.static_id) from apex_workspace_credentials c
                          where c.static_id = s.rs || '_CREDENTIALS'))    as credential_static_id,
               -- release 109: from APEX - the token URL of the Authentication Remote Server, the region and namespace of
               -- the Object Storage Remote Server URL (https://objectstorage.<region>.oraclecloud.com/n/<namespace>),
               -- the typed values of older servers are only the fallback
               s.auth_server_code,
               coalesce((select max(a.base_url) from apex_workspace_remote_servers a
                          where a.remote_server_static_id = s.auth_server_code), s.oauth_token_url) as oauth_token_url,
               coalesce(regexp_substr(coalesce(r.base_url, s.base_url), 'objectstorage\.([^.]+)\.', 1, 1, null, 1),
                        s.oci_region)                                       as oci_region,
               coalesce(regexp_substr(coalesce(r.base_url, s.base_url), '/n/([^/]+)', 1, 1, null, 1),
                        s.oci_namespace)                                    as oci_namespace,
               s.enabled_flag, s.description,
               -- calls and tests are logged under the server code or its Remote Server's static ID
               (select max(c.called_date) from xxfnd_integration_calls c
                 where c.server_static_id in (s.server_code, s.rs))        as last_call,
               (select max(c.called_date) from xxfnd_integration_calls c
                 where c.server_static_id in (s.server_code, s.rs) and c.status_code = 'FAILED') as last_error,
               (select max(t.result_code || ' ' || to_char(t.tested_date, 'DD-Mon-YYYY HH24:MI'))
                         keep (dense_rank last order by t.tested_date)
                  from xxfnd_server_tests t where t.server_static_id in (s.server_code, s.rs)) as last_test,
               rtrim(case when coalesce(r.base_url, s.base_url,
                                        case when s.server_type = 'OBJECT_STORAGE' then s.oci_region end) is null
                          then 'its APEX Remote Server, ' end
                  || case when s.credential_static_id is null
                           and not exists (select 1 from apex_appl_web_src_modules m
                                            where m.remote_server_static_id = s.rs
                                              and m.credential_static_id is not null)
                           and not exists (select 1 from apex_workspace_credentials c
                                            where c.static_id = s.rs || '_CREDENTIALS')
                          then 'a Web Credential, ' end
                  || case when s.server_type = 'OBJECT_STORAGE'
                           and (coalesce(regexp_substr(coalesce(r.base_url, s.base_url), 'objectstorage\.([^.]+)\.', 1, 1, null, 1), s.oci_region) is null
                                or coalesce(regexp_substr(coalesce(r.base_url, s.base_url), '/n/([^/]+)', 1, 1, null, 1), s.oci_namespace) is null)
                          then 'a Remote Server URL with the region and namespace, ' end
                  || case when s.server_type in ('SHAREPOINT', 'OUTLOOK') and s.oauth_token_url is null
                           and not exists (select 1 from apex_workspace_remote_servers a
                                            where a.remote_server_static_id = s.auth_server_code)
                          then 'an Authentication Remote Server (OAuth token URL), ' end, ', ')           as missing
          from (select x.*, nvl(x.remote_server_code, x.server_code) as rs from xxfnd_servers x) s
          left join apex_workspace_remote_servers r on r.remote_server_static_id = s.rs) q;
