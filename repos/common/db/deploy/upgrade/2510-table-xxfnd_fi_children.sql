--------------------------------------------------------------------------------
-- XXFND_FI_CHILDREN (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The child resources of an onboarded REST object (describe) and whether they are onboarded with it.
-- Idempotent: created only when missing (XXFND_DDL_PKG.CREATE_TABLE); later changes are checked steps.
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXFND_FI_CHILDREN', q'~create table xxfnd_fi_children (
    object_id              number         not null,
    child_name             varchar2(400)  not null,
    child_path             varchar2(1000),
    selected_flag          varchar2(1)    default 'N' not null,
    child_object_id        number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_fi_children_pk primary key (object_id, child_name),
    constraint xxfnd_fi_children_fk1 foreign key (object_id) references xxfnd_fi_objects (object_id) on delete cascade,
    constraint xxfnd_fi_children_fk2 foreign key (child_object_id) references xxfnd_fi_objects (object_id),
    constraint xxfnd_fi_children_ck1 check (selected_flag in ('Y', 'N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_fi_children is 'Release 107: the child resources of an onboarded REST object (from describe); a selected child becomes an object of its own (CHILD_OBJECT_ID).'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_FI_CHILDREN');
end;
/
