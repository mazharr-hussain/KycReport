
begin
    xxfnd_ddl_pkg.ensure_table('XXFND_LOOKUP_VALUES_TL', q'~create table xxfnd_lookup_values_tl (
    lookup_type            varchar2(30)   not null,
    lookup_code            varchar2(30)   not null,
    language_code          varchar2(10)   not null,
    meaning                varchar2(200)  not null,
    description            varchar2(500),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_lookup_values_tl_pk primary key (lookup_type, lookup_code, language_code),
    constraint xxfnd_lookup_values_tl_fk1 foreign key (lookup_type, lookup_code)
        references xxfnd_lookup_values (lookup_type, lookup_code) on delete cascade
)~');
end;
/
