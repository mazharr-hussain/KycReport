--------------------------------------------------------------------------------
-- Steps 4.0 and 5.3 (snapshot), run as the backup schema (proxy): copies the application's DATA (its tables, no code)
-- from the application schema. The previous copy is dropped first. Validation database only.
-- Not copied (reported): tables with LONG columns or columns of the application's own object types, queue tables,
-- materialized views and Oracle-internal tables. VPD adds no predicate outside an APEX session, so every row is read.
-- Substitution variable: app_schema (the application schema; it has granted SELECT through grant-to.sql).
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_src    constant varchar2(128) := dbms_assert.simple_sql_name(upper('&app_schema'));
    l_cols   varchar2(32767);
    l_tables pls_integer := 0;
    l_rows   number;
    l_total  number := 0;
begin
    for t in (select table_name from user_tables) loop
        execute immediate 'drop table "' || t.table_name || '" purge';
    end loop;
    for t in (select a.table_name,
                     (select count(*) from all_tab_cols c
                       where c.owner = a.owner and c.table_name = a.table_name
                         and (c.data_type = 'LONG' or c.data_type = 'LONG RAW' or c.data_type_owner = a.owner)) as blocked
                from all_tables a
               where a.owner = l_src and a.temporary = 'N' and a.nested = 'NO' and a.secondary = 'N'
                 and a.external = 'NO' and nvl(a.iot_type, 'IOT') = 'IOT' and a.dropped = 'NO'
                 and a.table_name not like 'BIN$%' and a.table_name not like 'SYS\_%' escape '\'
                 and a.table_name not like 'DR$%' and a.table_name not like 'MLOG$%' and a.table_name not like 'AQ$%'
                 and not exists (select 1 from all_mviews m where m.owner = a.owner and m.container_name = a.table_name)
                 and not exists (select 1 from all_queue_tables q where q.owner = a.owner and q.queue_table = a.table_name)
               order by a.table_name) loop
        if t.blocked > 0 then
            dbms_output.put_line('INFO not copied (LONG or object-type columns): ' || t.table_name);
            continue;
        end if;
        l_cols := null;
        for c in (select column_name from all_tab_cols
                   where owner = l_src and table_name = t.table_name and virtual_column = 'NO' and hidden_column = 'NO'
                   order by column_id) loop
            l_cols := l_cols || case when l_cols is not null then ', ' end || '"' || c.column_name || '"';
        end loop;
        execute immediate 'create table "' || t.table_name || '" as select ' || l_cols
            || ' from ' || l_src || '."' || t.table_name || '"';
        execute immediate 'select count(*) from "' || t.table_name || '"' into l_rows;
        l_tables := l_tables + 1;
        l_total  := l_total + l_rows;
    end loop;
    dbms_output.put_line('backup of ' || l_src || ' in ' || user || ': ' || l_tables || ' table(s), ' || l_total || ' row(s)');
end;
/
