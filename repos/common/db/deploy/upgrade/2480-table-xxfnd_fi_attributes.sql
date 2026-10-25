--------------------------------------------------------------------------------
-- XXFND_FI_ATTRIBUTES (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The attributes (columns) of an onboarded object from the live metadata: which are selected, primary keys, business names.
-- Idempotent: created only when missing (XXFND_DDL_PKG.CREATE_TABLE); later changes are checked steps.
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXFND_FI_ATTRIBUTES', q'~create table xxfnd_fi_attributes (
    object_id              number         not null,
    attribute_name         varchar2(400)  not null,
    column_name            varchar2(128)  not null,
    business_name          varchar2(400),
    data_type              varchar2(60)   not null,
    data_length            number,
    data_scale             number,
    pk_flag                varchar2(1)    default 'N' not null,
    selected_flag          varchar2(1)    default 'N' not null,
    custom_flag            varchar2(1)    default 'N' not null,
    last_update_flag       varchar2(1)    default 'N' not null,
    status_code            varchar2(10)   default 'ACTIVE' not null,
    display_sequence       number         default 100 not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_fi_attributes_pk primary key (object_id, attribute_name),
    constraint xxfnd_fi_attributes_uk1 unique (object_id, column_name),
    constraint xxfnd_fi_attributes_fk1 foreign key (object_id) references xxfnd_fi_objects (object_id) on delete cascade,
    constraint xxfnd_fi_attributes_ck1 check (pk_flag in ('Y', 'N') and selected_flag in ('Y', 'N')
                                              and custom_flag in ('Y', 'N') and last_update_flag in ('Y', 'N')),
    constraint xxfnd_fi_attributes_ck2 check (status_code in ('ACTIVE', 'REMOVED'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_fi_attributes is 'Release 107: the attributes of an onboarded Fusion object (live metadata): COLUMN_NAME in the generated tables and views, selected or not, primary key, custom (includeCustomization), last-update date (incremental extracts). A removed attribute is kept (STATUS REMOVED) for the views of older versions.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_FI_ATTRIBUTES');
end;
/
