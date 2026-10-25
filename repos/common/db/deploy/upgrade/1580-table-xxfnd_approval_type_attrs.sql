begin

    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_TYPE_ATTRS', q'~create table xxfnd_approval_type_attrs (
    approval_type_code     varchar2(30)   not null,
    attribute_code         varchar2(30)   not null,
    attribute_name         varchar2(100)  not null,
    lookup_type            varchar2(30),
    display_sequence       number         default 10 not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_type_attrs_pk primary key (approval_type_code, attribute_code),
    constraint xxfnd_approval_type_attrs_fk1 foreign key (approval_type_code)
        references xxfnd_approval_types (approval_type_code) on delete cascade
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_type_attrs is 'Approval Setup: the attributes a transaction type gives its rules (values from LOOKUP_TYPE when set).'~');
    end if;
end;
/
