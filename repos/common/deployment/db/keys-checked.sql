--------------------------------------------------------------------------------
-- Step 6.6 (part 2), run as the application schema (proxy) after the upgrade: every key is checked against the
-- existing rows. FAIL a key (primary, unique, foreign, check - a new required column too) that is on but not checked
-- (ENABLED NOVALIDATE): the upgrade did not prove the old rows meet it - unless the fresh install of this version
-- leaves it so too (novalidate_ok: its install script says "enable novalidate"): INFO. (Part 1, nothing lost, is
-- db/snapshot.sql + db/snapshot_compare.py - I-076: no backup schema.) Substitution variable: novalidate_ok.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_nv_ok    constant varchar2(32767) := ',' || upper(replace('&novalidate_ok', ' ')) || ',';
    l_lost     pls_integer := 0;
begin
    for k in (select table_name, constraint_name from user_constraints
               where status = 'ENABLED' and validated = 'NOT VALIDATED' and table_name not like 'XXCI\_%' escape '\'
                 and table_name not like 'BIN$%'
               order by table_name, constraint_name) loop
        if instr(l_nv_ok, ',' || k.table_name || '.' || k.constraint_name || ',') > 0 then
            dbms_output.put_line('INFO key not checked against the existing rows, as in the fresh install (enable novalidate by design): '
                || k.table_name || '.' || k.constraint_name);
        else
            dbms_output.put_line('FAIL key not checked against the existing rows: ' || k.table_name || '.' || k.constraint_name);
            l_lost := l_lost + 1;
        end if;
    end loop;
    if l_lost > 0 then
        raise_application_error(-20003, 'The upgrade left keys unchecked (' || l_lost || ') - see the FAIL lines.');
    end if;
    dbms_output.put_line('every key is checked against the existing rows');
end;
/
