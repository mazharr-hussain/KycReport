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

end xxfnd_ddl_pkg;
/

begin
    xxfnd_ddl_pkg.mark_release('R09', 'Release 9: deployment framework (baseline incl. install fixes and Chunk 0)');
    commit;
end;
/
