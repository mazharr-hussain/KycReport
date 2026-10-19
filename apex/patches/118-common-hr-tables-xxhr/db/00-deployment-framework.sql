--------------------------------------------------------------------------------
-- 00_deployment_framework.sql
-- Release tracking for chunk deployments. Every chunk ships one idempotent
-- upgrade script that (1) checks XXFND_DDL_PKG.RELEASE_APPLIED, (2) applies its
-- DDL with the checked helpers below, and (3) records itself with MARK_RELEASE.
-- Re-importing the same release therefore changes nothing.
-- Rule (release 69): no script may fail with ORA-00955 or change an object twice.
--   * Base table scripts (01-04) create a table, with its indexes and comments, only when it is missing
--     (CREATE_TABLE); an existing table is left as it is.
--   * Every change to an existing object is a checked step in a later script: ADD_COLUMN, DROP_COLUMN,
--     ADD_CONSTRAINT, DROP_CONSTRAINT, ENSURE_INDEX, DROP_INDEX, ENSURE_SEQUENCE. Each acts only when needed.
--------------------------------------------------------------------------------
create table if not exists xxfnd_schema_releases (
    release_code           varchar2(30)   not null,
    description            varchar2(400)  not null,
    applied_date           timestamp      default systimestamp not null,
    applied_by             varchar2(255)  not null,
    constraint xxfnd_schema_releases_pk primary key (release_code)
);

-- release 78: what DROP_OBJECT dropped - its DDL and the objects that depended on it (never purged)
create table if not exists xxfnd_dropped_objects (
    object_name            varchar2(128)  not null,
    object_type            varchar2(30)   not null,
    dependents             varchar2(4000),
    object_ddl             clob,
    dropped_date           timestamp      default systimestamp not null,
    dropped_by             varchar2(255)  not null
);

create or replace package xxfnd_ddl_pkg authid current_user as
    -- True once MARK_RELEASE has recorded this release in this schema.
    function release_applied(p_release_code in varchar2) return boolean;
    procedure mark_release(p_release_code in varchar2, p_description in varchar2);
    -- ALTER TABLE ... ADD (<column> <definition>) only when the column is missing.
    procedure add_column(p_table_name in varchar2, p_column_name in varchar2, p_definition in varchar2);
    -- Runs P_DDL (CREATE TABLE ...) and returns TRUE when the table is missing; returns FALSE and changes
    -- nothing when it exists. The caller creates the table's indexes and comments only on TRUE.
    function create_table(p_table_name in varchar2, p_ddl in varchar2) return boolean;
    -- The same for a table without indexes or comments.
    procedure ensure_table(p_table_name in varchar2, p_ddl in varchar2);
    -- Runs P_DDL (CREATE [UNIQUE] INDEX / CREATE SEQUENCE ...) only when the object is missing.
    procedure ensure_index(p_index_name in varchar2, p_ddl in varchar2);
    procedure ensure_sequence(p_sequence_name in varchar2, p_ddl in varchar2);
    -- ALTER TABLE ... DROP COLUMN / ADD CONSTRAINT / DROP CONSTRAINT, DROP INDEX only when needed.
    procedure drop_column(p_table_name in varchar2, p_column_name in varchar2);
    procedure add_constraint(p_table_name in varchar2, p_constraint_name in varchar2, p_definition in varchar2);
    procedure drop_constraint(p_table_name in varchar2, p_constraint_name in varchar2);
    procedure drop_index(p_index_name in varchar2);
    -- Release 78: DROP PACKAGE / VIEW / FUNCTION / PROCEDURE / SYNONYM only when the object exists. Safe sequence
    -- (DB skill): the objects that depend on it (every schema) and its DDL are recorded in XXFND_DROPPED_OBJECTS,
    -- this schema's synonyms for it are dropped, then the object (grants go with it; nothing is purged). Dependents
    -- are not a reason to stop: a dropped component breaks its old callers on purpose (no wrappers).
    -- Release 86: also TRIGGER; a TABLE only with p_retired_table => true (a retired table whose data was copied first,
    -- approved per table; it goes to the recycle bin, not purged; the foreign keys that point to it are dropped first
    -- with DROP_CONSTRAINT). Without it a table is still refused: tables keep their data.
    procedure drop_object(p_object_name in varchar2, p_object_type in varchar2, p_retired_table in boolean default false);
    -- Release 79: ALTER TABLE ... MODIFY (<column> NULL) only when the column is NOT NULL (no data changes).
    procedure set_nullable(p_table_name in varchar2, p_column_name in varchar2);
    -- Release 102: ALTER TABLE ... RENAME only when P_OLD_NAME exists and P_NEW_NAME does not; then the table's own
    -- constraints, indexes and triggers named P_OLD_NAME_... get the P_NEW_NAME_... name (also on a re-run, so a step
    -- stopped half way finishes). Rows, grants, policies and foreign keys stay with the table.
    procedure rename_table(p_old_name in varchar2, p_new_name in varchar2);
    -- EXECUTE IMMEDIATE, for the statements that belong to a table CREATE_TABLE just created.
    procedure run(p_ddl in varchar2);
end xxfnd_ddl_pkg;
/

create or replace package body xxfnd_ddl_pkg as

    function release_applied(p_release_code in varchar2) return boolean is
        l_count pls_integer;
    begin
        select count(*) into l_count from xxfnd_schema_releases where release_code = upper(p_release_code);
        return l_count > 0;
    end release_applied;

    procedure mark_release(p_release_code in varchar2, p_description in varchar2) is
    begin
        merge into xxfnd_schema_releases t
        using (select upper(p_release_code) release_code from dual) s
           on (t.release_code = s.release_code)
         when not matched then
            insert (release_code, description, applied_by)
            values (s.release_code, p_description,
                    coalesce(sys_context('APEX$SESSION', 'APP_USER'), sys_context('USERENV', 'SESSION_USER')));
    end mark_release;

    procedure add_column(p_table_name in varchar2, p_column_name in varchar2, p_definition in varchar2) is
        l_table  varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_column varchar2(128) := upper(dbms_assert.simple_sql_name(p_column_name));
        l_count  pls_integer;
    begin
        select count(*) into l_count from user_tab_columns where table_name = l_table and column_name = l_column;
        if l_count = 0 then
            execute immediate 'alter table ' || l_table || ' add (' || l_column || ' ' || p_definition || ')';
        end if;
    end add_column;

    function object_exists(p_name in varchar2, p_type in varchar2) return boolean is
        l_count pls_integer;
    begin
        select count(*) into l_count from user_objects
         where object_name = upper(dbms_assert.simple_sql_name(p_name)) and object_type = p_type;
        return l_count > 0;
    end object_exists;

    function constraint_exists(p_table_name in varchar2, p_constraint_name in varchar2) return boolean is
        l_count pls_integer;
    begin
        select count(*) into l_count from user_constraints
         where table_name = upper(dbms_assert.simple_sql_name(p_table_name))
           and constraint_name = upper(dbms_assert.simple_sql_name(p_constraint_name));
        return l_count > 0;
    end constraint_exists;

    procedure run(p_ddl in varchar2) is
    begin
        execute immediate p_ddl;
    end run;

    function create_table(p_table_name in varchar2, p_ddl in varchar2) return boolean is
    begin
        if object_exists(p_table_name, 'TABLE') then
            return false;
        end if;
        execute immediate p_ddl;
        return true;
    end create_table;

    procedure ensure_table(p_table_name in varchar2, p_ddl in varchar2) is
    begin
        if create_table(p_table_name, p_ddl) then
            null;
        end if;
    end ensure_table;

    procedure ensure_index(p_index_name in varchar2, p_ddl in varchar2) is
    begin
        if not object_exists(p_index_name, 'INDEX') then
            execute immediate p_ddl;
        end if;
    end ensure_index;

    procedure ensure_sequence(p_sequence_name in varchar2, p_ddl in varchar2) is
    begin
        if not object_exists(p_sequence_name, 'SEQUENCE') then
            execute immediate p_ddl;
        end if;
    end ensure_sequence;

    procedure drop_column(p_table_name in varchar2, p_column_name in varchar2) is
        l_count pls_integer;
    begin
        select count(*) into l_count from user_tab_columns
         where table_name = upper(dbms_assert.simple_sql_name(p_table_name))
           and column_name = upper(dbms_assert.simple_sql_name(p_column_name));
        if l_count > 0 then
            execute immediate 'alter table ' || p_table_name || ' drop column ' || p_column_name;
        end if;
    end drop_column;

    procedure add_constraint(p_table_name in varchar2, p_constraint_name in varchar2, p_definition in varchar2) is
    begin
        if not constraint_exists(p_table_name, p_constraint_name) then
            execute immediate 'alter table ' || p_table_name || ' add constraint ' || p_constraint_name || ' ' || p_definition;
        end if;
    end add_constraint;

    procedure drop_constraint(p_table_name in varchar2, p_constraint_name in varchar2) is
    begin
        if constraint_exists(p_table_name, p_constraint_name) then
            execute immediate 'alter table ' || p_table_name || ' drop constraint ' || p_constraint_name;
        end if;
    end drop_constraint;

    procedure drop_index(p_index_name in varchar2) is
    begin
        if object_exists(p_index_name, 'INDEX') then
            execute immediate 'drop index ' || p_index_name;
        end if;
    end drop_index;

    procedure rename_table(p_old_name in varchar2, p_new_name in varchar2) is
        l_old varchar2(128) := upper(dbms_assert.simple_sql_name(p_old_name));
        l_new varchar2(128) := upper(dbms_assert.simple_sql_name(p_new_name));
        function renamed(p_name in varchar2) return varchar2 is
        begin
            return dbms_assert.simple_sql_name(l_new || substr(p_name, length(l_old) + 1));
        end renamed;
    begin
        if object_exists(l_old, 'TABLE') and not object_exists(l_new, 'TABLE') then
            execute immediate 'alter table ' || l_old || ' rename to ' || l_new;
        end if;
        if not object_exists(l_new, 'TABLE') then
            return;
        end if;
        for c in (select constraint_name from user_constraints
                   where table_name = l_new and constraint_name like l_old || '\_%' escape '\') loop
            execute immediate 'alter table ' || l_new || ' rename constraint ' || c.constraint_name
                           || ' to ' || renamed(c.constraint_name);
        end loop;
        for i in (select index_name from user_indexes
                   where table_name = l_new and index_name like l_old || '\_%' escape '\') loop
            execute immediate 'alter index ' || i.index_name || ' rename to ' || renamed(i.index_name);
        end loop;
        for t in (select trigger_name from user_triggers
                   where table_name = l_new and trigger_name like l_old || '\_%' escape '\') loop
            execute immediate 'alter trigger ' || t.trigger_name || ' rename to ' || renamed(t.trigger_name);
        end loop;
    end rename_table;

    procedure drop_object(p_object_name in varchar2, p_object_type in varchar2, p_retired_table in boolean default false) is
        l_name  varchar2(128) := upper(dbms_assert.simple_sql_name(p_object_name));
        l_type  varchar2(30)  := upper(p_object_type);
        l_owner varchar2(128) := sys_context('USERENV', 'CURRENT_SCHEMA');
        l_ddl   clob;
        l_deps  varchar2(4000);
    begin
        if l_type not in ('PACKAGE', 'VIEW', 'FUNCTION', 'PROCEDURE', 'SYNONYM', 'TRIGGER')
           and not (l_type = 'TABLE' and p_retired_table) then
            raise_application_error(-20009, 'DROP_OBJECT does not drop a ' || l_type || ' (tables keep their data).');
        end if;
        if not object_exists(l_name, l_type) then
            return;
        end if;
        select substr(listagg(d.owner || '.' || d.name || ' (' || d.type || ')', ', ') within group (order by d.owner, d.name),
                      1, 4000)
          into l_deps
          from all_dependencies d
         where d.referenced_owner = l_owner and d.referenced_name = l_name
           and d.referenced_type in (l_type, l_type || ' BODY')
           and not (d.owner = l_owner and d.name = l_name);
        begin
            l_ddl := dbms_metadata.get_ddl(case l_type when 'PACKAGE' then 'PACKAGE' else l_type end, l_name);
        exception
            when others then
                l_ddl := null;   -- recorded without its DDL; the source is in the repository
        end;
        execute immediate 'insert into xxfnd_dropped_objects (object_name, object_type, dependents, object_ddl, dropped_by)'
                       || ' values (:1, :2, :3, :4, :5)'
            using l_name, l_type, l_deps, l_ddl,
                  coalesce(sys_context('APEX$SESSION', 'APP_USER'), sys_context('USERENV', 'SESSION_USER'));
        for s in (select synonym_name from user_synonyms where table_owner = l_owner and table_name = l_name) loop
            execute immediate 'drop synonym ' || dbms_assert.enquote_name(s.synonym_name, false);
        end loop;
        execute immediate 'drop ' || l_type || ' ' || l_name;
    end drop_object;

    procedure set_nullable(p_table_name in varchar2, p_column_name in varchar2) is
        l_table  varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_column varchar2(128) := upper(dbms_assert.simple_sql_name(p_column_name));
        l_count  pls_integer;
    begin
        select count(*) into l_count from user_tab_columns
         where table_name = l_table and column_name = l_column and nullable = 'N';
        if l_count > 0 then
            execute immediate 'alter table ' || l_table || ' modify (' || l_column || ' null)';
        end if;
    end set_nullable;

end xxfnd_ddl_pkg;
/

begin
    xxfnd_ddl_pkg.mark_release('R09', 'Release 9: deployment framework (baseline incl. install fixes and Chunk 0)');
    commit;
end;
/
