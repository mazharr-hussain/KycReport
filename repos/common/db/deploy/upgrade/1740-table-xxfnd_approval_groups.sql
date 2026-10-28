-- release 113: the approval groups of a process (approval type) - a named set of approvers (roles and users); a rule
-- level that names a group can be approved by anyone in it
begin
    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_GROUPS', q'~create table xxfnd_approval_groups (
    group_code             varchar2(30)   not null,
    approval_type_code     varchar2(30)   not null,
    group_name             varchar2(100)  not null,
    description            varchar2(1000),
    enabled_flag           varchar2(1)    default 'Y' not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_groups_pk primary key (group_code),
    constraint xxfnd_approval_groups_fk1 foreign key (approval_type_code) references xxfnd_approval_types (approval_type_code) on delete cascade,
    constraint xxfnd_approval_groups_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_groups is 'Release 113: approval groups of a process (approval type): a named set of approvers (XXFND_APPROVAL_GROUP_MEMBERS). A rule level of approver type GROUP names one in ROLE_CODE. Kept by XXFND_APPROVAL_RULE_PKG.SAVE_GROUP.'~');
    end if;
end;
/
