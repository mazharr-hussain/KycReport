-- release 113: the members of an approval group - roles (every active user of the role) and users
begin
    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_GROUP_MEMBERS', q'~create table xxfnd_approval_group_members (
    group_code             varchar2(30)   not null,
    member_type            varchar2(10)   not null,
    member_code            varchar2(255)  not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_group_members_pk primary key (group_code, member_type, member_code),
    constraint xxfnd_approval_group_members_fk1 foreign key (group_code) references xxfnd_approval_groups (group_code) on delete cascade,
    constraint xxfnd_approval_group_members_ck1 check (member_type in ('ROLE','USER'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_group_members is 'Release 113: members of an approval group: a ROLE (every active user of the role) or a USER. Kept by XXFND_APPROVAL_RULE_PKG.SET_GROUP_MEMBERS.'~');
    end if;
end;
/
