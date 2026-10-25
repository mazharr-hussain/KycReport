
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
