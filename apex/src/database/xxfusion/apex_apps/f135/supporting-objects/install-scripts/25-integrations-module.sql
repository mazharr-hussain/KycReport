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

-- the registered endpoints are read-only (retiring): the servers are APEX Remote Servers now
-- (release 86: only while the table exists - 29 copies it into XXFND_SERVERS and drops it)
declare
    l_n pls_integer;
begin
    select count(*) into l_n from user_tables where table_name = 'XXFND_INTEGRATION_ENDPOINTS';
    if l_n > 0 then
        execute immediate q'~create or replace trigger xxfnd_int_endpoints_ro
    before insert or update or delete on xxfnd_integration_endpoints
begin
    if xxfnd_util_pkg.in_apex_session then
        raise_application_error(-20316, 'Registered endpoints are read-only: servers are APEX Remote Servers, kept by '
            || 'the workspace administrator in Workspace Utilities.');
    end if;
end;~';
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

-- anything a change above left invalid is compiled again (no install error, no stale package state)
begin
    dbms_utility.compile_schema(schema => user, compile_all => false);
end;
/
