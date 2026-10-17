
begin
    if xxfnd_ddl_pkg.create_table('XXFND_ROLES', q'~create table xxfnd_roles (
    role_code              varchar2(30)   not null,
    application_code       varchar2(30)   not null,
    role_name              varchar2(200)  not null,
    description            varchar2(500),
    view_sensitive_flag    varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_roles_pk primary key (role_code),
    constraint xxfnd_roles_ck1 check (view_sensitive_flag in ('Y','N')),
    constraint xxfnd_roles_ck2 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~create index xxfnd_roles_n1 on xxfnd_roles (application_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_roles is 'Application roles. Enforced by APEX authorization schemes that call XXFND_USER_PKG.AUTHORIZED.'~');
    end if;
end;
/
