declare
    l_new boolean;
begin

    l_new := xxfnd_ddl_pkg.create_table('XXFND_DATA_OBJECTS', q'~create table xxfnd_data_objects (
    data_object_code       varchar2(60)   not null,
    object_name            varchar2(240)  not null,
    application_code       varchar2(30)   not null,
    table_name             varchar2(128)  not null,
    dimension_code         varchar2(30),
    dimension_column       varchar2(128),
    owner_column           varchar2(128),
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_data_objects_pk primary key (data_object_code),
    constraint xxfnd_data_objects_uk1 unique (table_name),
    constraint xxfnd_data_objects_fk1 foreign key (application_code) references xxfnd_applications (application_code) on delete cascade,
    constraint xxfnd_data_objects_fk2 foreign key (dimension_code) references xxfnd_data_dimensions (dimension_code),
    constraint xxfnd_data_objects_ck1 check ((dimension_code is null) = (dimension_column is null)),
    constraint xxfnd_data_objects_ck2 check (enabled_flag in ('Y','N'))
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_data_objects is 'Release 96: a secured table of an application (row policy XXFND_DATA_SECURITY): DIMENSION_COLUMN holds the value of DIMENSION_CODE (level VALUES), OWNER_COLUMN the user who owns a record (level OWN).'~');
    end if;
end;
/
