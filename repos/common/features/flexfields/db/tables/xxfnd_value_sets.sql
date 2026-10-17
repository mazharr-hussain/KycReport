
--==============================================================================
-- 0.5  DESCRIPTIVE FLEXFIELDS  (EBS: FND_FLEX_VALUE_SETS, FND_DESCRIPTIVE_FLEXS,
--      FND_DESCR_FLEX_CONTEXTS, FND_DESCR_FLEX_COLUMN_USAGES; Fusion typed segments)
--==============================================================================
begin
    if xxfnd_ddl_pkg.create_table('XXFND_VALUE_SETS', q'~create table xxfnd_value_sets (
    value_set_code         varchar2(60)   not null,
    value_set_name         varchar2(240)  not null,
    description            varchar2(1000),
    validation_type        varchar2(20)   not null,
    format_type            varchar2(20)   not null,
    maximum_size           number(4),
    number_precision       number(2),
    minimum_value          varchar2(150),
    maximum_value          varchar2(150),
    uppercase_only_flag    varchar2(1)    default 'N' not null,
    lookup_type            varchar2(30),
    parent_value_set_code  varchar2(60),
    table_query            clob,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_value_sets_pk primary key (value_set_code),
    constraint xxfnd_value_sets_fk1 foreign key (lookup_type) references xxfnd_lookup_types (lookup_type),
    constraint xxfnd_value_sets_fk2 foreign key (parent_value_set_code) references xxfnd_value_sets (value_set_code),
    constraint xxfnd_value_sets_ck1 check (validation_type in ('NONE','INDEPENDENT','DEPENDENT','TABLE')),
    constraint xxfnd_value_sets_ck2 check (format_type in ('CHAR','NUMBER','DATE','TIMESTAMP')),
    constraint xxfnd_value_sets_ck3 check (uppercase_only_flag in ('Y','N')),
    constraint xxfnd_value_sets_ck4 check (
        (validation_type = 'NONE'        and lookup_type is null and table_query is null) or
        (validation_type = 'INDEPENDENT' and lookup_type is not null and format_type = 'CHAR') or
        (validation_type = 'DEPENDENT'   and lookup_type is not null and parent_value_set_code is not null and format_type = 'CHAR') or
        (validation_type = 'TABLE'       and table_query is not null))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table  xxfnd_value_sets is 'Segment validation (FND_FLEX_VALUE_SETS). INDEPENDENT/DEPENDENT sets draw values from the Lookup engine; DEPENDENT uses the parent columns on XXFND_LOOKUP_VALUES.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_value_sets.table_query is 'TABLE validation only. Must return RETURN_VALUE and DISPLAY_VALUE; may reference :CONTEXT_CODE.'~');
    end if;
end;
/
-- Release 86: REGISTER_VALUE_SET reads the value set's application; on older databases 16i adds that column, a fresh
-- install needs it before this body compiles (checked step: nothing when it exists).
begin
    xxfnd_ddl_pkg.add_column('XXFND_VALUE_SETS', 'APPLICATION_CODE', 'varchar2(30)');
end;
/
--------------------------------------------------------------------------------
-- 16i Administration scope (release 61). Installed by the COMMON application only (XXFUSION).
--   Each COMMON setup screen works for one application at a time (G_ADMIN_APP): it shows and changes only that
--   application's rows (and, for a Common Administrator, the shared rows: application empty).
--   - An application column on value sets, retention policies and storage rules (release 86: integration endpoints retired)
--     (the other setup tables already have one; empty = shared by all applications).
--   Release 73: no application filter for IT; delegated administration - an application's administrators open
--   the COMMON screens of the functions IT lets them manage, from their own application, for its rows only.
--   - Scope functions (release 80: XXFND_APPLICATION_PKG, 09d): the applications the signed-in user administers -
--     every application for a Common Administrator (role COMMON_ADMIN), otherwise the applications of the user's
--     active roles that hold an admin privilege.
-- Idempotent.
--------------------------------------------------------------------------------
-- application scope columns (empty = shared)
declare
    l_n pls_integer;
begin
    for t in (select column_value table_name
                from table(apex_t_varchar2('XXFND_VALUE_SETS', 'XXFND_RETENTION_POLICIES', 'XXFND_STORAGE_CONFIG'))) loop
        -- release 86: XXFND_INTEGRATION_ENDPOINTS retired (29); the servers (XXFND_SERVERS) are workspace-wide
        select count(*) into l_n from user_tab_columns where table_name = t.table_name and column_name = 'APPLICATION_CODE';
        if l_n = 0 then
            execute immediate 'alter table ' || t.table_name || ' add (application_code varchar2(30))';
        end if;
    end loop;
end;
/

comment on column xxfnd_value_sets.application_code            is 'Application the value set belongs to; empty = shared by all applications.';
