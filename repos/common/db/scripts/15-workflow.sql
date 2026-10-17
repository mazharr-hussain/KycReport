
-- Release 88 (C6): the contacts an application holds for its records (e.g. the contacts of a party), offered as the
-- recipients on the COMMON e-mail page 46. An application registers a view of its own schema per entity
-- (XXFND_NOTIFY_PKG.REGISTER_CONTACT_SOURCE) with the columns PK1_VALUE, CONTACT_NAME, EMAIL_ADDRESS, and grants SELECT
-- on it to COMMON's schema.
begin
    if xxfnd_ddl_pkg.create_table('XXFND_CONTACT_SOURCES', q'~create table xxfnd_contact_sources (
    entity_name            varchar2(60)   not null,
    application_code       varchar2(30)   not null,
    source_view            varchar2(128)  not null,
    description            varchar2(4000),
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_contact_sources_pk primary key (entity_name),
    constraint xxfnd_contact_sources_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade,
    constraint xxfnd_contact_sources_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_contact_sources is 'Release 88: the contacts of an application''s records (a view of the application''s schema with PK1_VALUE, CONTACT_NAME, EMAIL_ADDRESS), offered as recipients on the COMMON e-mail page.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_CONTACT_SOURCES');
end;
/

create or replace type xxfnd_contact_row force as object (
    contact_name   varchar2(400),
    email_address  varchar2(320)
);
/
create or replace type xxfnd_contact_tab force as table of xxfnd_contact_row;
/
