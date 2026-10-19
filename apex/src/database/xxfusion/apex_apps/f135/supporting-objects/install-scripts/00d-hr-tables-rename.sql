--------------------------------------------------------------------------------
-- 00d HR tables (release 102). COMMON only; runs on install and on every upgrade, before the base table scripts.
--   Employees and organizations (departments, ...) are HR data: their tables carry the XXHR_ prefix, not XXFND_.
--     XXFND_EMPLOYEES     -> XXHR_EMPLOYEES
--     XXFND_ORGANIZATIONS -> XXHR_ORGANIZATIONS
--   XXFND_DDL_PKG.RENAME_TABLE renames a table only while the old one exists and the new one does not, with its own
--   constraints, indexes and triggers; rows, grants, data security policies and foreign keys stay with the table.
--   A fresh install has nothing to rename: 01 and 09a then create the XXHR_ tables (only when they are missing).
--   The setup rows that name a table (audited tables, data model groups, data objects, ...) get the new name.
--   The applications' synonyms follow in their own install (03 / 00c drop the old ones and create the new ones).
-- Idempotent: a re-run renames and updates nothing.
--------------------------------------------------------------------------------
declare
    type t_pair is record (old_name varchar2(128), new_name varchar2(128));
    type t_pairs is table of t_pair;
    l_pairs t_pairs := t_pairs();
    l_n     pls_integer;

    procedure pair(p_old in varchar2, p_new in varchar2) is
    begin
        l_pairs.extend;
        l_pairs(l_pairs.last).old_name := p_old;
        l_pairs(l_pairs.last).new_name := p_new;
    end pair;
begin
    pair('XXFND_EMPLOYEES',     'XXHR_EMPLOYEES');
    pair('XXFND_ORGANIZATIONS', 'XXHR_ORGANIZATIONS');

    for i in 1 .. l_pairs.count loop
        xxfnd_ddl_pkg.rename_table(l_pairs(i).old_name, l_pairs(i).new_name);
        -- setup rows that hold the table name (the audit log keeps the name it had when the change was made)
        for t in (select c.table_name from user_tab_columns c
                   where c.column_name = 'TABLE_NAME'
                     and c.table_name in ('XXFND_CONFIG_TABLES', 'XXFND_DM_TABLE_GROUPS', 'XXFND_DATA_OBJECTS',
                                          'XXFND_DATA_SECURITY_RULES', 'XXFND_RETENTION_POLICIES',
                                          'XXFND_DOCUMENT_ENTITIES', 'XXFND_DF_FLEXFIELDS', 'XXFND_SETUP_TYPES')
                     and exists (select 1 from user_tables u where u.table_name = c.table_name)) loop
            execute immediate 'select count(*) from ' || t.table_name || ' where table_name = :o'
               into l_n using l_pairs(i).old_name;
            if l_n > 0 then
                execute immediate 'update ' || t.table_name || ' set table_name = :n where table_name = :o'
                  using l_pairs(i).new_name, l_pairs(i).old_name;
                dbms_output.put_line(t.table_name || ': ' || sql%rowcount || ' row(s) now name ' || l_pairs(i).new_name);
            end if;
        end loop;
    end loop;
    commit;
end;
/
