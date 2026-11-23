--------------------------------------------------------------------------------
-- Steps 4.5 and 5.8, run as the application schema (proxy): the schema's structure, one line per item, so the fresh
-- install (4.5, kept in XXCI_FRESH_SCHEMA) and the upgraded database (5.8) can be compared line by line:
--   T <table> | C <table>.<column> <type>(<length>,<precision>,<scale>) <nullable> | K <table> <constraint> <type>
--   <status> <validated> | I <table> <index> <uniqueness> | O <type> <name> <status>   (sorted)
-- and R <table> <rows> (row counts: compared for information only). System-named constraints and indexes (SYS_...),
-- LOB indexes, the pipeline's own XXCI_ tables and the release record are left out.
--------------------------------------------------------------------------------
set define off verify off feedback off heading off pagesize 0 linesize 4000 trimspool on serveroutput on size unlimited
declare
    l_n number;
begin
    for r in (
        select 'T ' || table_name as line from user_tables
         where table_name not like 'XXCI\_%' escape '\' and table_name not like 'BIN$%' and temporary = 'N'
        union all
        select 'C ' || c.table_name || '.' || c.column_name || ' ' || c.data_type
               || '(' || c.char_length || ',' || c.data_precision || ',' || c.data_scale || ') ' || c.nullable
          from user_tab_columns c join user_tables t on t.table_name = c.table_name
         where c.table_name not like 'XXCI\_%' escape '\' and t.temporary = 'N'
        union all
        select 'K ' || table_name || ' ' || constraint_name || ' ' || constraint_type || ' ' || status || ' ' || validated
          from user_constraints
         where constraint_name not like 'SYS\_%' escape '\' and constraint_name not like 'BIN$%'
           and table_name not like 'XXCI\_%' escape '\' and constraint_type in ('P', 'U', 'R', 'C')
        union all
        select 'I ' || table_name || ' ' || index_name || ' ' || uniqueness from user_indexes
         where index_name not like 'SYS\_%' escape '\' and index_type <> 'LOB' and index_name not like 'BIN$%'
           and table_name not like 'XXCI\_%' escape '\'
        union all
        select 'O ' || object_type || ' ' || object_name || ' ' || status from user_objects
         where object_type in ('PACKAGE', 'PACKAGE BODY', 'VIEW', 'TRIGGER', 'TYPE', 'TYPE BODY', 'FUNCTION',
                               'PROCEDURE', 'SEQUENCE', 'SYNONYM', 'MATERIALIZED VIEW')
           and object_name not like 'ISEQ$$%' and object_name not like 'BIN$%' and object_name not like 'XXCI\_%' escape '\'
         order by 1) loop
        dbms_output.put_line('SCHEMA ' || r.line);
    end loop;
    for t in (select table_name from user_tables
               where table_name not like 'XXCI\_%' escape '\' and table_name not like 'BIN$%' and temporary = 'N'
               order by table_name) loop
        begin
            execute immediate 'select count(*) from "' || t.table_name || '"' into l_n;
        exception
            when others then l_n := -1;   -- e.g. a row policy that cannot run outside an APEX session
        end;
        dbms_output.put_line('SCHEMA R ' || t.table_name || ' ' || l_n);
    end loop;
end;
/
