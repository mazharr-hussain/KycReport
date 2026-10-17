--------------------------------------------------------------------------------
-- 33 Data Model (release 89). COMMON only (XXFUSION), after 32 and before 99.
--   The objects of every registered application, read live from the database dictionary: the Object Catalogue
--   (COMMON pages 175 / 176) and the entity-relationship diagram (page 177). An application's objects are the
--   objects of its schema (XXFND_APPLICATIONS.SCHEMA_NAME), narrowed by its optional object prefix
--   (XXFND_DM_APP_SCOPES); its tables may be grouped for the diagram (XXFND_DM_TABLE_GROUPS). IT sees every
--   application, an application's administrators only their own (feature DATA_MODEL managed in the application).
--   The XXFND_DM_*_V views read the DBA_ dictionary views when COMMON's schema has been granted them
--   (apex/db/admin/grant-dictionary-to-xxfusion.sql, by ADMIN; then run this script again: Install Supporting
--   Objects), else the ALL_ views (COMMON's own objects and what it may see of other schemas).
--   XXFND_DATA_MODEL_PKG: the visibility rule, the prefix and group routines, the diagram source (Mermaid text).
-- Idempotent: a re-run changes nothing (the views are rebuilt; a re-run after the grants switches them to DBA_).
--------------------------------------------------------------------------------
declare
    l_new boolean;
begin
    l_new := xxfnd_ddl_pkg.create_table('XXFND_DM_APP_SCOPES', q'~create table xxfnd_dm_app_scopes (
    application_code       varchar2(30)   not null,
    object_prefix          varchar2(30)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_dm_app_scopes_pk primary key (application_code),
    constraint xxfnd_dm_app_scopes_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_dm_app_scopes is 'Release 89: the object prefix of an application in its schema (Data Model): only the objects whose name starts with it are the application''s. No row = every object of the schema.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_DM_APP_SCOPES');
    l_new := xxfnd_ddl_pkg.create_table('XXFND_DM_TABLE_GROUPS', q'~create table xxfnd_dm_table_groups (
    application_code       varchar2(30)   not null,
    table_name             varchar2(128)  not null,
    group_name             varchar2(100)  not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_dm_table_groups_pk primary key (application_code, table_name),
    constraint xxfnd_dm_table_groups_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_dm_table_groups is 'Release 89: the group (module, area) of an application''s table in the Data Model diagram (XXFND_DATA_MODEL_PKG.REGISTER_TABLE_GROUP).'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_DM_TABLE_GROUPS');
end;
/
