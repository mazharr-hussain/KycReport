-- COMMON 110: a purpose takes its endpoint from an APEX REST Source Catalog service. Run as XXFUSION in an APEX
-- session of an administrator with Integrations - Manage. Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_svc  number;
    l_val  number;
    l_resp clob;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    -- I-059: the APEX session of the tests' administrator ADMIN (tests/setup/03_common_test_fixture.sql)
    apex_util.set_workspace('XXCUS');
    apex_session.create_session(p_app_id => 135, p_page_id => 1, p_username => 'ADMIN');
    select count(*) into l_val from user_tab_columns
     where table_name = 'XXFND_INTEGRATION_PURPOSES' and column_name = 'CATALOG_SERVICE_ID';
    ok('column CATALOG_SERVICE_ID exists', l_val = 1);
    select min(service_id) into l_svc from apex_rest_catalog_services;
    if l_svc is null then
        dbms_output.put_line('SKIP no REST Source Catalog service in the workspace');
    else
        xxfnd_integration_pkg.save_purpose('R110_TEST', 'R110 test', 'COMMON', 'API', null, null, 'Y', l_svc);
        select catalog_service_id into l_val from xxfnd_integration_purposes where purpose_code = 'R110_TEST';
        ok('catalog service saved', l_val = l_svc);
        begin
            l_resp := xxfnd_integration_pkg.call('R110_TEST');
            ok('call ran on the catalog endpoint', true);
        exception
            when others then
                ok('call used the catalog endpoint (not ORA-20312): ' || sqlerrm, sqlcode <> -20312);
        end;
    end if;
    begin
        xxfnd_integration_pkg.save_purpose('R110_NONE', 'R110 none', 'COMMON', 'API', null, null, 'Y');
        l_resp := xxfnd_integration_pkg.call('R110_NONE');
        ok('purpose without endpoint refused', false);
    exception
        -- release 86 (CK5): such a purpose is already refused when it is saved; else the call refuses it (ORA-20312)
        when others then ok('purpose without endpoint refused (' || sqlerrm || ')', sqlcode in (-20312, -2290));
    end;
    rollback;
end;
/
