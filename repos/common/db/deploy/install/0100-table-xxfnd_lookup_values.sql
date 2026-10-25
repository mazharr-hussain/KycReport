
begin
    if xxfnd_ddl_pkg.create_table('XXFND_LOOKUP_VALUES', q'~create table xxfnd_lookup_values (
    lookup_type            varchar2(30)   not null,
    lookup_code            varchar2(30)   not null,
    meaning                varchar2(200)  not null,
    description            varchar2(500),
    tag                    varchar2(150),
    parent_lookup_type     varchar2(30),
    parent_lookup_code     varchar2(30),
    display_sequence       number,
    enabled_flag           varchar2(1)    default 'Y' not null,
    start_date_active      date           default trunc(sysdate) not null,
    end_date_active        date,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_lookup_values_pk primary key (lookup_type, lookup_code),
    constraint xxfnd_lookup_values_fk1 foreign key (lookup_type) references xxfnd_lookup_types (lookup_type),
    constraint xxfnd_lookup_values_fk2 foreign key (parent_lookup_type, parent_lookup_code)
        references xxfnd_lookup_values (lookup_type, lookup_code),
    constraint xxfnd_lookup_values_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_lookup_values_ck2 check (end_date_active is null or end_date_active >= start_date_active)
)~') then
        xxfnd_ddl_pkg.run(q'~create index xxfnd_lookup_values_n1 on xxfnd_lookup_values (parent_lookup_type, parent_lookup_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table  xxfnd_lookup_values is 'Lookup values (FND_LOOKUP_VALUES). Parent columns support dependent (cascading) values.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_lookup_values.tag is 'One extra attribute for a value, e.g. a jurisdiction''s UBO threshold. Needs more than one? Use a dedicated table.'~');
    end if;
end;
/
