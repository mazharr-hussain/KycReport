
--------------------------------------------------------------------------------
-- release 48: configuration tables of each application (shared module): which tables get the configuration
-- audit trigger and which are under maker-checker (Config Change Approvals). Each application registers its own
-- tables, so the shared code names no application table.
--   PK_COLUMN       - key of a maker-checker row
--   UNIT_TABLE / UNIT_KEY_COLUMN - rows approved together under one task (e.g. answer options of one question:
--                     XXAPP_QUESTIONS / QUESTION_ID); null = each row on its own (unit = the table itself)
--   CHANGES_VIEW    - the application's view of its pending changes, one row per approval unit, columns
--                     DETAIL_PK ('<unit table>:<key>'), CHANGE_TYPE, CHANGE_TITLE, CHANGE_SUMMARY, SUBMITTED_BY,
--                     SUBMITTED_DATE
--------------------------------------------------------------------------------
create table if not exists xxfnd_config_tables (
    table_name             varchar2(128)  not null,
    application_id         number         not null,
    audit_flag             varchar2(1)    default 'Y' not null,
    approval_flag          varchar2(1)    default 'N' not null,
    pk_column              varchar2(128),
    unit_table             varchar2(128),
    unit_key_column        varchar2(128),
    changes_view           varchar2(128),
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_config_tables_pk primary key (table_name),
    constraint xxfnd_config_tables_fk1 foreign key (application_id) references xxfnd_applications (application_id),
    constraint xxfnd_config_tables_ck1 check (audit_flag in ('Y','N')),
    constraint xxfnd_config_tables_ck2 check (approval_flag in ('Y','N')),
    constraint xxfnd_config_tables_ck3 check (approval_flag = 'N' or (pk_column is not null and changes_view is not null)),
    constraint xxfnd_config_tables_ck4 check (table_name = upper(table_name))
);
comment on table xxfnd_config_tables is 'Configuration tables per application: configuration audit (AUDIT_FLAG) and maker-checker approval (APPROVAL_FLAG, PK_COLUMN, UNIT_TABLE / UNIT_KEY_COLUMN, CHANGES_VIEW).';
