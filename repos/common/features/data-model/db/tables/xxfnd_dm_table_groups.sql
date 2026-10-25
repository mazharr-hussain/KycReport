declare
    l_new boolean;
begin
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
end;
/
