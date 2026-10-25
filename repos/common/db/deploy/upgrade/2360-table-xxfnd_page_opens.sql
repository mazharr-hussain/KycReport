
-- release 106: the pages users opened a COMMON page from (another application's page), counted
begin
    if xxfnd_ddl_pkg.create_table('XXFND_PAGE_OPENS', q'~create table xxfnd_page_opens (
    from_app_alias         varchar2(255)  not null,
    from_page              varchar2(255)  not null,
    to_application_id      number         not null,
    to_page_id             number         not null,
    open_count             number         default 0 not null,
    first_opened_date      timestamp      not null,
    last_opened_date       timestamp      not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_page_opens_pk primary key (from_app_alias, from_page, to_application_id, to_page_id)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_page_opens is 'Release 106: a COMMON page opened from a page of another application (the referrer), with how often and when; recorded by XXFND_NAV_PKG.RECORD_OPEN, shown as Opened From on the Application Menu page catalogue.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_page_opens.from_page is 'The page of the other application: its number or its alias, as in the URL.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_PAGE_OPENS');
end;
/
