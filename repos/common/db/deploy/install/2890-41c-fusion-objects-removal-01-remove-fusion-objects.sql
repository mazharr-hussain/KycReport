--------------------------------------------------------------------------------
-- 41c COMMON 112: the Fusion Objects engine (release 107) is removed - Fusion endpoints come from the APEX REST
-- Source Catalogs on the servers. This script takes back what 40z registered (feature FUSION_OBJECTS with its
-- privileges and pages, its menu entry, purpose FUSION_OBJECTS while it has no logged calls, template XXFND_FI_ALERT,
-- messages XXFND_FI_*), drops the engine packages, then drops each engine table only while it holds no rows (recorded
-- in XXFND_DROPPED_OBJECTS); a table with rows, and any replica the engine generated, is kept as it is.
-- Re-runnable: nothing happens once everything is gone.
--------------------------------------------------------------------------------
declare
    l_n pls_integer;
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- COMMON's own menu entry (made by SYNC_MENU, which only adds)
    delete from xxfnd_app_menu_entries
     where application_code = 'COMMON' and entry_code = 'F_FUSION_OBJECTS' and made_by = 'COMMON';
    xxfnd_privilege_pkg.unregister_feature('COMMON', 'FUSION_OBJECTS');
    select count(*) into l_n from xxfnd_integration_calls where purpose_code = 'FUSION_OBJECTS';
    if l_n = 0 then
        xxfnd_integration_pkg.unregister_purpose('COMMON', 'FUSION_OBJECTS');
    end if;
    xxfnd_notify_pkg.unregister_template('COMMON', 'XXFND_FI_ALERT');
    delete from xxfnd_messages where message_code like 'XXFND\_FI\_%' escape '\';
    xxfnd_util_pkg.set_install_mode(false);
    commit;

    for p in (select column_value name from table(apex_t_varchar2(
                  'XXFND_FI_RUN_PKG', 'XXFND_FI_DRIFT_PKG', 'XXFND_FI_REGISTRY_PKG', 'XXFND_FI_GEN_PKG', 'XXFND_FI_META_PKG')))
    loop
        xxfnd_ddl_pkg.drop_object(p.name, 'PACKAGE');
    end loop;
    -- children first: a table is dropped only while it is empty
    for t in (select column_value name from table(apex_t_varchar2(
                  'XXFND_FI_RUNS', 'XXFND_FI_DRIFT', 'XXFND_FI_VERSIONS', 'XXFND_FI_CHILDREN', 'XXFND_FI_ATTRIBUTES',
                  'XXFND_FI_OBJECTS', 'XXFND_FI_CATALOG')))
    loop
        select count(*) into l_n from user_tables where table_name = t.name;
        if l_n > 0 then
            execute immediate 'select count(*) from ' || t.name || ' where rownum = 1' into l_n;
            if l_n = 0 then
                xxfnd_ddl_pkg.drop_object(t.name, 'TABLE', p_retired_table => true);
            end if;
        end if;
    end loop;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
