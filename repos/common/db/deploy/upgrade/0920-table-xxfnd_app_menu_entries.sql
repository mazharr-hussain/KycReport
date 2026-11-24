
-- release 87: the menu each application shows for the common functions (entries made by ONBOARD, maintained in COMMON)
begin
    if xxfnd_ddl_pkg.create_table('XXFND_APP_MENU_ENTRIES', q'~create table xxfnd_app_menu_entries (
    application_code       varchar2(30)   not null,
    entry_code             varchar2(60)   not null,
    label                  varchar2(100)  not null,
    parent_code            varchar2(60),
    display_sequence       number         default 100 not null,
    icon_css               varchar2(100),
    target_type            varchar2(20)   not null,
    page_id                number,
    feature_code           varchar2(30),
    enabled_flag           varchar2(1)    default 'Y' not null,
    made_by                varchar2(10)   default 'COMMON' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_app_menu_entries_pk primary key (application_code, entry_code),
    constraint xxfnd_app_menu_entries_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade,
    constraint xxfnd_app_menu_entries_ck1 check (target_type in ('COMMON_PAGE', 'APP_PAGE', 'MANAGED', 'SHARED_SETUP')),
    constraint xxfnd_app_menu_entries_ck2 check (enabled_flag in ('Y','N')),
    constraint xxfnd_app_menu_entries_ck3 check (made_by in ('COMMON','APP')),
    constraint xxfnd_app_menu_entries_ck4 check (target_type in ('MANAGED', 'SHARED_SETUP') or page_id is not null)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_app_menu_entries is 'The menu entries of each application for the common functions (release 87): made by XXFND_APPLICATION_PKG.ONBOARD / ENSURE_MENU or the application (REGISTER_MENU_ENTRY), maintained in COMMON; read through XXFND_APP_MENU_V.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_app_menu_entries.target_type is 'COMMON_PAGE: a COMMON page; APP_PAGE: a page of the application; MANAGED: a common function the application manages (COMMON page 99 for the application); SHARED_SETUP: COMMON Administration (page 100).'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_app_menu_entries.feature_code is 'The feature whose VIEW privilege shows the entry; empty = every signed-in user.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_APP_MENU_ENTRIES');
    -- release 105: the menu an entry belongs to - SIDE (navigation menu), TOP_BAR (navigation bar), ADMIN
    -- (Administration page); every entry so far is a SIDE entry
    xxfnd_ddl_pkg.add_column('XXFND_APP_MENU_ENTRIES', 'MENU_CODE', q'~varchar2(20) default 'SIDE' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK10',
        q'~check (menu_code in ('SIDE', 'TOP_BAR', 'ADMIN'))~');
end;
/
