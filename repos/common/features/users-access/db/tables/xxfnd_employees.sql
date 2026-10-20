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
--   Release 102 fix: until every script of this upgrade has recreated its code with the new names, the code of the
--   installed release still names the old tables (packages, triggers, the policy functions of the setup tables).
--   Synonyms with the old names (XXFND_EMPLOYEES -> XXHR_EMPLOYEES, ...) keep that code valid during the upgrade;
--   the last script (99z) drops them. A fresh install needs none.
-- Idempotent: a re-run renames and updates nothing.
--------------------------------------------------------------------------------
declare
    type t_pair is record (old_name varchar2(128), new_name varchar2(128));
    type t_pairs is table of t_pair;
    l_pairs t_pairs := t_pairs();
    l_n     pls_integer;
    l_rids  dbms_sql.varchar2_table;
    l_moved pls_integer;
    l_gone  pls_integer;

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
        -- the old name, for the old code, until 99z
        select count(*) into l_n from user_objects where object_name = l_pairs(i).old_name;
        if l_n = 0 then
            select count(*) into l_n from user_tables where table_name = l_pairs(i).new_name;
            if l_n > 0 then
                execute immediate 'create synonym ' || l_pairs(i).old_name || ' for ' || l_pairs(i).new_name;
            end if;
        end if;
        -- setup rows that hold the table name (the audit log keeps the name it had when the change was made)
        for t in (select c.table_name from user_tab_columns c
                   where c.column_name = 'TABLE_NAME'
                     and c.table_name in ('XXFND_CONFIG_TABLES', 'XXFND_DM_TABLE_GROUPS', 'XXFND_DATA_OBJECTS',
                                          'XXFND_DATA_SECURITY_RULES', 'XXFND_RETENTION_POLICIES',
                                          'XXFND_DOCUMENT_ENTITIES', 'XXFND_DF_FLEXFIELDS', 'XXFND_SETUP_TYPES')
                     and exists (select 1 from user_tables u where u.table_name = c.table_name)) loop
            -- release 102 fix: row by row - a row the new release already registered under the new name (e.g. 04b's
            -- audited tables, after an upgrade that stopped half way) stays, and the old-name row is the duplicate
            execute immediate 'select rowidtochar(rowid) from ' || t.table_name || ' where table_name = :o'
               bulk collect into l_rids using l_pairs(i).old_name;
            l_moved := 0;
            l_gone  := 0;
            for r in 1 .. l_rids.count loop
                begin
                    execute immediate 'update ' || t.table_name || ' set table_name = :n where rowid = chartorowid(:r)'
                      using l_pairs(i).new_name, l_rids(r);
                    l_moved := l_moved + 1;
                exception
                    when dup_val_on_index then
                        execute immediate 'delete from ' || t.table_name || ' where rowid = chartorowid(:r)'
                          using l_rids(r);
                        l_gone := l_gone + 1;
                end;
            end loop;
            if l_rids.count > 0 then
                dbms_output.put_line(t.table_name || ': ' || l_moved || ' row(s) now name ' || l_pairs(i).new_name
                                     || ', ' || l_gone || ' duplicate old-name row(s) removed');
            end if;
        end loop;
    end loop;
    commit;
end;
/
--------------------------------------------------------------------------------
-- 99z HR tables: the old names go (release 102). COMMON only; the last script of install and upgrade.
--   Script 00d keeps synonyms with the old names (XXFND_EMPLOYEES, XXFND_ORGANIZATIONS) while an upgrade runs, so the
--   code of the installed release stays valid until its script recreates it with the XXHR_ names. Every script has
--   run now: the synonyms are dropped (XXFND_DDL_PKG.DROP_OBJECT records anything that still depended on them).
-- Idempotent: drops only a synonym that exists.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.drop_object('XXFND_EMPLOYEES', 'SYNONYM');
    xxfnd_ddl_pkg.drop_object('XXFND_ORGANIZATIONS', 'SYNONYM');
end;
/
