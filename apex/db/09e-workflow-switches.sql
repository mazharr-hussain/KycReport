--------------------------------------------------------------------------------
-- 09e Workflow and e-mail switches (release 73). COMMON only (XXFUSION). Early, so the shared packages that
--   follow (15 notifications) can ask it.
--   - XXFND_WORKFLOW_PROCESSES: one row per workflow process (APEX workflow static ID) of each registered
--     application. WORKFLOW_ENABLED_FLAG N = the approval is skipped and the record is auto-approved
--     ("Auto-approved (workflow disabled)"); EMAIL_ENABLED_FLAG N = no e-mails for the process.
--   - XXFND_APPLICATIONS.EMAIL_ENABLED_FLAG: e-mail on / off for an application; the COMMON row is the instance.
--   An e-mail is sent only when the instance, the application and the process all have e-mail on. Tasks and
--   in-application notifications do not depend on the e-mail switches.
--   Release 82: the switch routines are in XXFND_WORKFLOW_PKG (15).
-- Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATIONS', 'EMAIL_ENABLED_FLAG', q'~varchar2(1) default 'Y' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPLICATIONS', 'XXFND_APPLICATIONS_CK_EMAIL', q'~check (email_enabled_flag in ('Y','N'))~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_applications.email_enabled_flag is 'E-mail on / off for the application (the COMMON row: for the whole instance).'~');

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
    xxfnd_schema_pkg.create_who_trigger('XXFND_WORKFLOW_PROCESSES');
end;
/

