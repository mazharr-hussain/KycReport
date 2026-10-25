declare
    l_new boolean;
begin

    l_new := xxfnd_ddl_pkg.create_table('XXFND_ROLE_MEMBERS', q'~create table xxfnd_role_members (
    role_code              varchar2(30)   not null,
    member_role_code       varchar2(30)   not null,
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_role_members_pk primary key (role_code, member_role_code),
    constraint xxfnd_role_members_fk1 foreign key (role_code) references xxfnd_roles (role_code) on delete cascade,
    constraint xxfnd_role_members_fk2 foreign key (member_role_code) references xxfnd_roles (role_code) on delete cascade,
    constraint xxfnd_role_members_ck1 check (role_code <> member_role_code)
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~create index xxfnd_role_members_n1 on xxfnd_role_members (member_role_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_role_members is 'Release 96: roles inside roles. A user holding ROLE_CODE also has MEMBER_ROLE_CODE (and its members), with their privileges and data access.'~');
    end if;
end;
/
