--------------------------------------------------------------------------------
-- 01_xxfnd_tables.sql
-- Common, reusable components (XXFND_). Any application in workspace XXCUS
-- may use these objects. KYC-specific objects live in 02_xxcmp_tables.sql.
--
--   0.0  Lookups, identity and access, notification templates, audit, retention
--   0.1  Attachments (EBS FND attachments model; UCM or SharePoint storage)
--   0.2  Workflow engine
--   0.4  Integration hub
--   0.5  Descriptive flexfields (EBS structure, Fusion typed segments)
--
-- Conventions
--   * Surrogate keys are identity columns; stable setup data uses natural keys.
--   * Every table carries the standard WHO columns; XXFND_UTIL_PKG creates the
--     trigger that fills them and increments OBJECT_VERSION_NUMBER.
--   * ENABLED_FLAG plus START/END_DATE_ACTIVE where effective dating applies.
--   * Single-column lookup codes are validated by LOVs and packages, not by a
--     foreign key, because XXFND_LOOKUP_VALUES has a two-column key (the same
--     approach as FND_LOOKUP_VALUES).
--   * _TL tables hold translated text; LANGUAGE_CODE uses APEX language codes
--     ('en', 'ar'). A missing translation falls back to the base row.
--------------------------------------------------------------------------------

--==============================================================================
-- 0.0  LOOKUPS
--==============================================================================
begin
    if xxfnd_ddl_pkg.create_table('XXFND_LOOKUP_TYPES', q'~create table xxfnd_lookup_types (
    lookup_type            varchar2(30)   not null,
    meaning                varchar2(200)  not null,
    description            varchar2(500),
    application_code       varchar2(30),
    customization_level    varchar2(1)    default 'U' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_lookup_types_pk primary key (lookup_type),
    constraint xxfnd_lookup_types_ck1 check (customization_level in ('S','E','U'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table  xxfnd_lookup_types is 'Lookup type header (FND_LOOKUP_TYPES). APPLICATION_CODE null = shared by every application.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_lookup_types.customization_level is 'S = system (values locked), E = extensible (values may be added), U = user (fully editable).'~');
    end if;
end;
/
