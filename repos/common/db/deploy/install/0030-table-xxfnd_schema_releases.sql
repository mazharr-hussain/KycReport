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
