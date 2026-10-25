
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
