--------------------------------------------------------------------------------
-- 05b step 9 (release 110): XXFND_INTEGRATION_PURPOSES.CATALOG_SERVICE_ID - the APEX REST Source Catalog service
-- (APEX_REST_CATALOG_SERVICES.SERVICE_ID) that gives the purpose its endpoint, so the endpoint is kept in APEX.
-- Idempotent: the column is added only when missing.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_INTEGRATION_PURPOSES', 'CATALOG_SERVICE_ID', 'number');
    execute immediate q'~comment on column xxfnd_integration_purposes.catalog_service_id is 'Release 110: APEX REST Source Catalog service (APEX_REST_CATALOG_SERVICES.SERVICE_ID) whose URL endpoint the call uses on the purpose''s server; the REST Data Source is the fallback.'~';
end;
/
