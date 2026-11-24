--------------------------------------------------------------------------------
-- 41a COMMON 108 cleanup: XXFND_TRANSMISSIONS was never used (no routine or page writes or reads it) and is no
-- longer created. On a database that has it, it is dropped only while it holds no rows (recorded in
-- XXFND_DROPPED_OBJECTS); a table with rows is kept as it is. Re-runnable: nothing happens once it is gone.
--------------------------------------------------------------------------------
declare
    l_n pls_integer;
begin
    select count(*) into l_n from user_tables where table_name = 'XXFND_TRANSMISSIONS';
    if l_n > 0 then
        execute immediate 'select count(*) from xxfnd_transmissions where rownum = 1' into l_n;
        if l_n = 0 then
            xxfnd_ddl_pkg.drop_object('XXFND_TRANSMISSIONS', 'TABLE', p_retired_table => true);
        end if;
    end if;
end;
/
