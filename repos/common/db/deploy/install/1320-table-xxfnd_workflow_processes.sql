begin

    if xxfnd_ddl_pkg.create_table('XXFND_WORKFLOW_PROCESSES', q'~create table xxfnd_workflow_processes (
    application_code       varchar2(30)   not null,
    process_code           varchar2(255)  not null,
    process_name           varchar2(255),
    workflow_enabled_flag  varchar2(1)    default 'Y' not null,
    email_enabled_flag     varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_workflow_processes_pk primary key (application_code, process_code),
    constraint xxfnd_workflow_processes_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade,
    constraint xxfnd_workflow_processes_ck1 check (workflow_enabled_flag in ('Y','N')),
    constraint xxfnd_workflow_processes_ck2 check (email_enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_workflow_processes is 'Workflow processes (APEX workflow static ID) per application: approval workflow on / off (off = auto-approved) and e-mail on / off.'~');
    end if;
end;
/
