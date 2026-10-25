
create table if not exists xxfnd_role_privileges (
    role_code              varchar2(30)   not null,
    privilege_code         varchar2(61)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_role_privileges_pk primary key (role_code, privilege_code),
    constraint xxfnd_role_privileges_fk1 foreign key (role_code) references xxfnd_roles (role_code) on delete cascade,
    constraint xxfnd_role_privileges_fk2 foreign key (privilege_code) references xxfnd_privileges (privilege_code) on delete cascade
);
comment on table xxfnd_role_privileges is 'Privileges granted to a role. Maintained on the Roles and Privileges screen.';
