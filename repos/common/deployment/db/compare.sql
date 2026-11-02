--------------------------------------------------------------------------------
-- Step 7.5, run as the application schema (proxy) after the upgrade: nothing may be lost. Compares every table with
-- the backup schema's snapshot taken just before the upgrade (7.3). Validation database only.
--   FAIL  a table that still exists has fewer rows than before the upgrade (data lost)
--   INFO  a table removed by the release; rows whose values the upgrade changed (planned data changes)
-- Large-object and object-type columns are not compared value by value (row counts still are).
-- Substitution variables: bkp_schema, restore_exclude.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_bkp      constant varchar2(128) := dbms_assert.simple_sql_name(upper('&bkp_schema'));
    l_exclude  constant varchar2(4000) := ',' || upper(replace('&restore_exclude', ' ')) || ',';
    l_cols     varchar2(32767);
    l_before   number;
    l_after    number;
    l_changed  number;
    l_tables   pls_integer := 0;
    l_lost     pls_integer := 0;
begin
    for t in (select b.table_name,
                     (select count(*) from user_tables u where u.table_name = b.table_name) as still_there
                from all_tables b
               where b.owner = l_bkp and instr(l_exclude, ',' || b.table_name || ',') = 0
               order by b.table_name) loop
        execute immediate 'select count(*) from ' || l_bkp || '."' || t.table_name || '"' into l_before;
        if t.still_there = 0 then
            dbms_output.put_line('INFO removed by the release: ' || t.table_name || ' (' || l_before || ' row(s) before)');
            continue;
        end if;
        l_tables := l_tables + 1;
        execute immediate 'select count(*) from "' || t.table_name || '"' into l_after;
        if l_after < l_before then
            dbms_output.put_line('FAIL data lost: ' || t.table_name || ' had ' || l_before || ' row(s), now ' || l_after);
            l_lost := l_lost + 1;
            continue;
        end if;
        l_cols := null;
        for c in (select u.column_name from user_tab_cols u
                   where u.table_name = t.table_name and u.virtual_column = 'NO' and u.hidden_column = 'NO'
                     and u.data_type not in ('CLOB', 'NCLOB', 'BLOB', 'BFILE', 'LONG', 'LONG RAW', 'XMLTYPE', 'JSON')
                     and u.data_type_owner is null
                     and exists (select 1 from all_tab_cols b
                                  where b.owner = l_bkp and b.table_name = u.table_name and b.column_name = u.column_name)
                   order by u.column_id) loop
            l_cols := l_cols || case when l_cols is not null then ', ' end || '"' || c.column_name || '"';
        end loop;
        if l_cols is not null then
            execute immediate 'select count(*) from (select ' || l_cols || ' from ' || l_bkp || '."' || t.table_name
                || '" minus select ' || l_cols || ' from "' || t.table_name || '")' into l_changed;
            if l_changed > 0 then
                dbms_output.put_line('INFO changed by the upgrade: ' || t.table_name || ' - ' || l_changed || ' row(s)');
            end if;
        end if;
    end loop;
    dbms_output.put_line('compared ' || l_tables || ' table(s) with the snapshot before the upgrade');
    if l_lost > 0 then
        raise_application_error(-20003, 'The upgrade lost data in ' || l_lost || ' table(s) - see the FAIL lines.');
    end if;
end;
/
