
create table if not exists xxfnd_applications (
    application_id         number         default on null xxfnd_applications_s.nextval not null,
    application_code       varchar2(30)   not null,
    application_name       varchar2(240)  not null,
    apex_app_alias         varchar2(255),
    apex_application_id    number,
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_applications_pk primary key (application_id),
    constraint xxfnd_applications_uk1 unique (application_code),
    constraint xxfnd_applications_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_applications_ck2 check (application_code = upper(application_code))
);
comment on table xxfnd_applications is 'Applications that use the shared access module (roles, features, users). APPLICATION_ID = internal key, never changed; APPLICATION_CODE / APEX_APP_ALIAS = the same in every environment; APEX_APPLICATION_ID = the APEX ID in this environment.';

declare
    procedure run(p_sql in varchar2) is
    begin
        execute immediate p_sql;
    exception
        when others then
            -- ORA-02275 / ORA-02261 / ORA-01451 / ORA-00955: the constraint / index already exists or the column is already nullable
            if sqlcode not in (-2275, -2261, -1451, -955) then
                raise;
            end if;
    end run;
begin
    -- roles and grants of the shared module refer to the application and the user
    -- release 47: internal key from the sequence; the APEX ID in its own column; the alias identifies the app
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATIONS', 'APEX_APPLICATION_ID', 'number');
    run('alter table xxfnd_applications modify (application_id default on null xxfnd_applications_s.nextval)');
    run('alter table xxfnd_applications add constraint xxfnd_applications_uk2 unique (apex_app_alias)');
    xxfnd_ddl_pkg.add_column('XXFND_ROLES', 'APPLICATION_ID', 'number');
    xxfnd_ddl_pkg.add_column('XXFND_USER_ROLES', 'USER_ID', 'number');
    run('alter table xxfnd_user_roles modify (employee_id null)');
    run('alter table xxfnd_roles add constraint xxfnd_roles_fk1 foreign key (application_id) references xxfnd_applications (application_id)');
    run('alter table xxfnd_user_roles add constraint xxfnd_user_roles_fk3 foreign key (user_id) references xxfnd_users (user_id)');
    run('create index xxfnd_roles_n2 on xxfnd_roles (application_id)');
    run('create index xxfnd_user_roles_n3 on xxfnd_user_roles (user_id)');
    -- one open-ended grant per user and role
    -- ORA-02264: name already used by an existing constraint
    begin
        execute immediate 'alter table xxfnd_user_roles add constraint xxfnd_user_roles_ck3 check (user_id is not null) enable novalidate';
    exception when others then if sqlcode <> -2264 then raise; end if;
    end;
    run('create unique index xxfnd_user_roles_u2 on xxfnd_user_roles ('
        || 'case when end_date_active is null and user_id is not null then user_id end, '
        || 'case when end_date_active is null and user_id is not null then role_code end)');
    -- release 76: the grants belong to the user (U2); the employee index U1 refused the same role to a second LOCAL user
    -- (no employee) - checked drop, nothing to do when it is gone
    xxfnd_ddl_pkg.drop_index('XXFND_USER_ROLES_U1');
end;
/

comment on column xxfnd_applications.apex_application_id is 'APEX application ID in this environment (may differ between DEV / TEST / PROD); set at sign-in from the alias.';

-- release 54: the database schema of each application. Its own objects live there; the shared XXFND_ objects
-- live only in the COMMON application's schema (XXFUSION), and each application schema reaches them through
-- synonyms and grants (xxfnd_share_pkg).
begin
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATIONS', 'SCHEMA_NAME', 'varchar2(128)');
end;
/
comment on column xxfnd_applications.schema_name is 'Database schema of the application''s own objects (KYC: XXCUS; COMMON: XXFUSION, which owns the shared XXFND_ objects).';
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
    -- release 82: who acts on the process - RULE (the Approval Setup rules decide) or CHOSEN (the user who starts it
    -- chooses, e.g. the recipient of a request for information); before XXFND_WORKFLOW_PKG (15) reads the table
    xxfnd_ddl_pkg.add_column('XXFND_WORKFLOW_PROCESSES', 'PARTICIPANTS_TYPE', q'~varchar2(30) default 'RULE' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_WORKFLOW_PROCESSES', 'XXFND_WORKFLOW_PROCESSES_CK3',
        q'~check (participants_type in ('RULE','CHOSEN'))~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_workflow_processes.participants_type is 'Who acts on the process: RULE = the Approval Setup rules decide; CHOSEN = the user who starts it chooses (e.g. the recipient of a request for information).'~');
end;
/

