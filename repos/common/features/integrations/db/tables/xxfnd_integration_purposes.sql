
begin
    if xxfnd_ddl_pkg.create_table('XXFND_INTEGRATION_PURPOSES', q'~create table xxfnd_integration_purposes (
    purpose_code           varchar2(30)   not null,
    application_code       varchar2(30),
    purpose_name           varchar2(200)  not null,
    endpoint_code          varchar2(30),
    capture_method         varchar2(20)   default 'MANUAL' not null,
    approval_status        varchar2(20)   default 'DRAFT' not null,
    approved_by            varchar2(255),
    approved_date          timestamp,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_int_purposes_pk primary key (purpose_code),
    constraint xxfnd_int_purposes_fk1 foreign key (endpoint_code) references xxfnd_integration_endpoints (endpoint_code),
    constraint xxfnd_int_purposes_ck1 check (capture_method in ('MANUAL','API')),
    constraint xxfnd_int_purposes_ck2 check (approval_status in ('DRAFT','PENDING_APPROVAL','APPROVED','REJECTED')),
    constraint xxfnd_int_purposes_ck3 check (capture_method = 'MANUAL' or endpoint_code is not null)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_integration_purposes is 'Which endpoint serves each business purpose, and whether it runs manually or by API. Changes take effect only after a second person approves them.'~');
    end if;
end;
/
--------------------------------------------------------------------------------
-- 25 Integrations module (release 83, C6). COMMON only (XXFUSION), after 24.
--   Servers are APEX Remote Servers and Web Credentials of the workspace (COMMON workspace components: FUSION,
--   UCM_MAIN, SHAREPOINT_MAIN, OUTLOOK_GRAPH; the workspace administrator sets their URLs and secrets); endpoints are
--   REST Data Sources of COMMON (FUSION_HCM_WORKERS). XXFND_INTEGRATION_PKG (05b) calls them and logs every call.
--   - XXFND_INTEGRATION_ENDPOINTS is read-only and retiring: its rows stay (no data deleted), nothing changes them.
--   - A purpose that runs by API needs a REST Data Source (or, until it retires, an endpoint).
--   - Purpose HCM_SYNC: the Fusion HCM worker sync (REST Data Source FUSION_HCM_WORKERS on server FUSION).
--   - The Integrations screens: Servers (120) instead of Endpoints.
-- Idempotent: checked steps; a re-run changes nothing.
--------------------------------------------------------------------------------
-- release 86: not again once 29 replaced CK4 by CK5 (an API purpose needs a REST Data Source or a server)
declare
    l_n pls_integer;
begin
    select count(*) into l_n from user_constraints where constraint_name = 'XXFND_INT_PURPOSES_CK5';
    if l_n = 0 then
        xxfnd_ddl_pkg.drop_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_CK3');
        xxfnd_ddl_pkg.add_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_CK4',
            q'~check (capture_method = 'MANUAL' or rest_source_static_id is not null or endpoint_code is not null)~');
    end if;
end;
/

begin
    xxfnd_util_pkg.set_install_mode(true);
    merge into xxfnd_integration_purposes t using (select 'HCM_SYNC' purpose_code from dual) s
       on (t.purpose_code = s.purpose_code)
     when not matched then insert (purpose_code, application_code, purpose_name, capture_method, rest_source_static_id,
                                   approval_status, approved_by, approved_date)
                           values ('HCM_SYNC', 'COMMON', 'Fusion HCM worker sync', 'API', 'FUSION_HCM_WORKERS',
                                   'APPROVED', 'INSTALL', systimestamp);
    update xxfnd_feature_pages set tab_label = 'Servers'
     where app_alias = 'COMMON' and page_id = 120 and tab_label = 'Endpoints';
    update xxfnd_features
       set description = 'Servers (APEX Remote Servers and Web Credentials) with their health, the purposes they serve and '
                         || 'the log of every call.'
     where feature_code = 'INTEGRATIONS' and description not like 'Servers (APEX Remote Servers%';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

-- 3. purposes: the server of the old endpoint; an API purpose needs a REST Data Source or a server
begin
    xxfnd_util_pkg.set_install_mode(true);
    update xxfnd_integration_purposes p
       set p.server_code = p.endpoint_code
     where p.server_code is null
       and p.endpoint_code is not null
       and exists (select 1 from xxfnd_servers s where s.server_code = p.endpoint_code);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_ddl_pkg.drop_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_CK4');
    xxfnd_ddl_pkg.add_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_CK5',
        q'~check (capture_method = 'MANUAL' or rest_source_static_id is not null or server_code is not null)~');
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
comment on column xxfnd_integration_purposes.endpoint_code is 'Before release 86: the retired integration endpoint. No longer read (SERVER_CODE).';
