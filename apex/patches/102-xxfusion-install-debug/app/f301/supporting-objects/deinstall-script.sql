-- Patch 102: remove the test table with the application.
declare
    l_count pls_integer;
begin
    select count(*) into l_count from user_tables where table_name = 'XXFTEST_PING';
    if l_count = 1 then
        execute immediate 'drop table xxftest_ping purge';
    end if;
end;
/
