-- COMMON 112: servers linked to their APEX Remote Server (name and URL read from it), REST Source Catalogs of a server,
-- Fusion Objects removed. Run as XXFUSION in an APEX session of an administrator with Integrations - Manage.
-- Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_rs  varchar2(255);
    l_n   pls_integer;
    l_cat number;
    l_v   xxfnd_servers_v%rowtype;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select count(*) into l_n from user_tab_columns where table_name = 'XXFND_SERVERS' and column_name = 'REMOTE_SERVER_CODE';
    ok('REMOTE_SERVER_CODE exists', l_n = 1);
    select count(*) into l_n from user_tab_columns where table_name = 'XXFND_SERVERS' and column_name = 'SOURCE_APPLICATION_ID';
    ok('SOURCE_APPLICATION_ID dropped', l_n = 0);
    select min(remote_server_static_id) into l_rs from apex_workspace_remote_servers;
    if l_rs is null then
        dbms_output.put_line('SKIP no APEX Remote Server in the workspace');
    else
        -- a server with its own code, linked to an existing Remote Server
        xxfnd_integration_pkg.save_server(p_server_code => 'R112_SRV', p_server_name => 'typed name', p_server_type => 'REST',
                                          p_remote_server_code => l_rs);
        select * into l_v from xxfnd_servers_v where server_code = 'R112_SRV';
        for r in (select remote_server_name, base_url from apex_workspace_remote_servers where remote_server_static_id = l_rs) loop
            ok('name read from the Remote Server: ' || l_v.server_name, l_v.server_name = r.remote_server_name);
            ok('URL read from the Remote Server: ' || l_v.base_url, l_v.base_url = r.base_url);
        end loop;
        ok('linked Remote Server shown', l_v.remote_server_code = l_rs);
        select min(catalog_id) into l_cat from apex_rest_catalogs;
        if l_cat is not null then
            xxfnd_integration_pkg.set_server_catalogs('R112_SRV', to_char(l_cat));
            select count(*) into l_n from xxfnd_server_catalogs where server_code = 'R112_SRV';
            ok('catalog linked to the server', l_n = 1);
            xxfnd_integration_pkg.set_server_catalogs('R112_SRV', null);
            select count(*) into l_n from xxfnd_server_catalogs where server_code = 'R112_SRV';
            ok('catalog taken off the server', l_n = 0);
        else
            dbms_output.put_line('SKIP no REST Source Catalog in the workspace');
        end if;
    end if;
    -- Fusion Objects is gone
    select count(*) into l_n from user_objects where object_name like 'XXFND\_FI\_%\_PKG' escape '\';
    ok('Fusion Objects packages dropped', l_n = 0);
    select count(*) into l_n from xxfnd_features where feature_code = 'FUSION_OBJECTS';
    ok('feature FUSION_OBJECTS removed', l_n = 0);
    select count(*) into l_n from xxfnd_app_menu_entries where entry_code = 'F_FUSION_OBJECTS';
    ok('menu entry removed', l_n = 0);
    rollback;
end;
/
