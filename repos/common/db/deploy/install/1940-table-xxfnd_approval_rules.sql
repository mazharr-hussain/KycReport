begin

    if xxfnd_ddl_pkg.create_table('XXFND_APPROVAL_RULES', q'~create table xxfnd_approval_rules (
    rule_id                number         not null,
    approval_type_code     varchar2(30)   not null,
    rule_name              varchar2(100)  not null,
    priority               number         default 100 not null,
    description            varchar2(1000),
    enabled_flag           varchar2(1)    default 'Y' not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxfnd_approval_rules_pk primary key (rule_id),
    constraint xxfnd_approval_rules_uk1 unique (approval_type_code, rule_name),
    constraint xxfnd_approval_rules_fk1 foreign key (approval_type_code)
        references xxfnd_approval_types (approval_type_code) on delete cascade,
    constraint xxfnd_approval_rules_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_approval_rules is 'Approval Setup: rules of a transaction type. The enabled rule whose conditions match most attributes applies; then the lowest priority.'~');
    end if;
end;
/
