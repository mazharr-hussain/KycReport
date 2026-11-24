declare
    l_new boolean;
begin

    l_new := xxfnd_ddl_pkg.create_table('XXFND_DATA_DIMENSIONS', q'~create table xxfnd_data_dimensions (
    dimension_code         varchar2(30)   not null,
    dimension_name         varchar2(240)  not null,
    application_code       varchar2(30)   default 'COMMON' not null,
    value_source           varchar2(20)   default 'ORGANIZATION' not null,
    organization_type      varchar2(30),
    lookup_type            varchar2(30),
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_data_dimensions_pk primary key (dimension_code),
    constraint xxfnd_data_dimensions_fk1 foreign key (application_code) references xxfnd_applications (application_code),
    constraint xxfnd_data_dimensions_ck1 check (value_source in ('ORGANIZATION','LOOKUP','FREE')),
    constraint xxfnd_data_dimensions_ck2 check ((value_source = 'ORGANIZATION' and organization_type is not null)
                                             or (value_source = 'LOOKUP' and lookup_type is not null)
                                             or value_source = 'FREE'),
    constraint xxfnd_data_dimensions_ck3 check (enabled_flag in ('Y','N'))
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_data_dimensions is 'Release 96: what data access is decided by (Department, Country, ...). Values: XXHR_ORGANIZATIONS of ORGANIZATION_TYPE, a lookup type, or FREE text.'~');
    end if;
end;
/
