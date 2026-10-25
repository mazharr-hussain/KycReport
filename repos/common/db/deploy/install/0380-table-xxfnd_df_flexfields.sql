
begin
    if xxfnd_ddl_pkg.create_table('XXFND_DF_FLEXFIELDS', q'~create table xxfnd_df_flexfields (
    descriptive_flexfield_code varchar2(60) not null,
    application_code       varchar2(30),
    table_name             varchar2(128)  not null,
    pk_column_name         varchar2(128)  not null,
    context_column_name    varchar2(128)  default 'ATTRIBUTE_CATEGORY' not null,
    context_reference_column varchar2(128),
    default_context_code   varchar2(80),
    context_required_flag  varchar2(1)    default 'N' not null,
    context_user_selectable_flag varchar2(1) default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_df_flexfields_pk primary key (descriptive_flexfield_code),
    constraint xxfnd_df_flexfields_uk1 unique (table_name),
    constraint xxfnd_df_flexfields_ck1 check (context_required_flag in ('Y','N')),
    constraint xxfnd_df_flexfields_ck2 check (context_user_selectable_flag in ('Y','N')),
    constraint xxfnd_df_flexfields_ck3 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table  xxfnd_df_flexfields is 'One DFF per table (FND_DESCRIPTIVE_FLEXS). Registering a table here plus enabling contexts and segments is all it takes for every screen carrying the DFF region to render the fields.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_df_flexfields.context_reference_column is 'Derive the context from this column on the same row, e.g. JURISDICTION (FND_DEFAULT_CONTEXT_FIELDS).'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_df_flexfields.context_user_selectable_flag is 'Y = when no reference column, the user picks the context from a list.'~');
    end if;
end;
/
