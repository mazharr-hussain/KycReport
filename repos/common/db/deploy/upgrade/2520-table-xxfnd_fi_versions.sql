--------------------------------------------------------------------------------
-- XXFND_FI_VERSIONS (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The metadata versions of an onboarded object: the attribute snapshot, its hash and the business view of that version.
-- Idempotent: created only when missing (XXFND_DDL_PKG.CREATE_TABLE); later changes are checked steps.
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXFND_FI_VERSIONS', q'~create table xxfnd_fi_versions (
    object_id              number         not null,
    version_no             number         not null,
    metadata_hash          varchar2(64)   not null,
    metadata_json          clob,
    view_name              varchar2(128),
    harvested_date         timestamp      default systimestamp not null,
    applied_date           timestamp,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_fi_versions_pk primary key (object_id, version_no),
    constraint xxfnd_fi_versions_fk1 foreign key (object_id) references xxfnd_fi_objects (object_id) on delete cascade,
    constraint xxfnd_fi_versions_ck1 check (metadata_json is json)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_fi_versions is 'Release 107: each metadata version of an onboarded object (selected attributes as JSON, SHA-256 hash) with its versioned business view XXFI_<code>_V<n>; the stable view XXFI_<code>_V selects from the applied one.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_FI_VERSIONS');
end;
/
