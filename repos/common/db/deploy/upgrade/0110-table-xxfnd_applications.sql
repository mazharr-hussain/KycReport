
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
