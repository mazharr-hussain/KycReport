
declare
    l_new boolean;
begin
    l_new := xxfnd_ddl_pkg.create_table('XXFND_SETUP_TYPES', q'~create table xxfnd_setup_types (
    setup_type_code        varchar2(30)   not null,
    setup_type_name        varchar2(100)  not null,
    feature_code           varchar2(30),
    table_name             varchar2(128),
    list_page_id           number,
    form_page_id           number,
    allowed_level          varchar2(1)    default 'B' not null,
    all_applications_flag  varchar2(1)    default 'Y' not null,
    display_sequence       number         default 100 not null,
    description            varchar2(400),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_setup_types_pk primary key (setup_type_code),
    constraint xxfnd_setup_types_ck1 check (allowed_level in ('I','A','B')),
    constraint xxfnd_setup_types_ck2 check (all_applications_flag in ('Y','N'))
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_setup_types is 'Setup types and the level they are kept at: I instance only (application empty), A application only, B either; ALL_APPLICATIONS_FLAG N = only the applications in XXFND_SETUP_TYPE_APPS.'~');
    end if;
end;
/
