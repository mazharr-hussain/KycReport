--------------------------------------------------------------------------------
-- Data Model (COMMON release 89): lets COMMON read the database dictionary of every application's schema.
-- Run once as ADMIN (Database Actions > SQL > Run Script), then in App Builder: COMMON > Utilities > Supporting
-- Objects > Install Supporting Objects (script 33 rebuilds the Data Model views on the DBA_ dictionary views).
-- Without these grants the Data Model shows COMMON's own objects and what COMMON may already read of other schemas.
-- Read-only: SELECT on the dictionary views used, nothing else. Re-runnable.
-- If a grant is refused (for example on Autonomous Database, where ADMIN may not pass on these SYS views), use instead:
--   grant select any dictionary to xxfusion;
--------------------------------------------------------------------------------
begin
    for v in (select column_value name from table(sys.odcivarchar2list(
                  'DBA_OBJECTS', 'DBA_TAB_COMMENTS', 'DBA_COL_COMMENTS', 'DBA_TAB_COLS', 'DBA_CONSTRAINTS',
                  'DBA_CONS_COLUMNS', 'DBA_INDEXES', 'DBA_IND_COLUMNS', 'DBA_IND_EXPRESSIONS', 'DBA_TRIGGERS',
                  'DBA_PROCEDURES', 'DBA_ARGUMENTS', 'DBA_TYPE_ATTRS', 'DBA_DEPENDENCIES', 'DBA_TAB_PRIVS',
                  'DBA_POLICIES'))) loop
        execute immediate 'grant select on sys.' || v.name || ' to xxfusion';
        dbms_output.put_line('granted: select on ' || v.name);
    end loop;
end;
/
