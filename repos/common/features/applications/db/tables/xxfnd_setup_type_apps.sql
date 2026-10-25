declare
    l_new boolean;
begin

    if xxfnd_ddl_pkg.create_table('XXFND_SETUP_TYPE_APPS', q'~create table xxfnd_setup_type_apps (
    setup_type_code        varchar2(30)   not null,
    application_code       varchar2(30)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_setup_type_apps_pk primary key (setup_type_code, application_code),
    constraint xxfnd_setup_type_apps_fk1 foreign key (setup_type_code)
        references xxfnd_setup_types (setup_type_code) on delete cascade,
    constraint xxfnd_setup_type_apps_fk2 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_setup_type_apps is 'Applications a setup type may be kept for (when its ALL_APPLICATIONS_FLAG is N).'~');
    end if;
end;
/
