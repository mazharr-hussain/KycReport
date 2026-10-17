-- KYC release 92 (run as XXCUS): XXCMP_UBO_DETERMINATIONS is retired.
--   - the table is marked retired, its rows stay; its index is gone; no package or view reads it
--   - (18h no longer registers the lookup UBO_STATUS)
set serveroutput on size unlimited feedback off
declare
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function cnt(p_sql varchar2) return number is
        l number;
    begin
        execute immediate p_sql into l;
        return l;
    end;
begin
    ok('XXCMP_UBO_DETERMINATIONS is marked retired',
       cnt(q'[select count(*) from user_tab_comments where table_name = 'XXCMP_UBO_DETERMINATIONS' and comments like 'Retired%']') = 1);
    ok('its index XXCMP_UBO_DETERMINATIONS_N1 is gone',
       cnt(q'[select count(*) from user_indexes where index_name = 'XXCMP_UBO_DETERMINATIONS_N1']') = 0);
    ok('no package or view reads it',
       cnt(q'[select count(*) from user_dependencies where referenced_name = 'XXCMP_UBO_DETERMINATIONS'
               and type in ('PACKAGE', 'PACKAGE BODY', 'VIEW', 'FUNCTION', 'PROCEDURE')]') = 0);
    ok('no invalid object in the KYC schema',
       cnt(q'[select count(*) from user_objects where status <> 'VALID' and object_name not like 'BIN$%']') = 0);
exception
    when others then
        dbms_output.put_line('FAIL unexpected: ' || sqlerrm || ' ' || dbms_utility.format_error_backtrace);
end;
/
