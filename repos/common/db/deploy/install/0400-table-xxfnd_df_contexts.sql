
begin
    if xxfnd_ddl_pkg.create_table('XXFND_DF_CONTEXTS', q'~create table xxfnd_df_contexts (
    descriptive_flexfield_code varchar2(60) not null,
    context_code           varchar2(80)   not null,
    context_name           varchar2(240)  not null,
    description            varchar2(1000),
    global_flag            varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    protected_flag         varchar2(1)    default 'N' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_df_contexts_pk primary key (descriptive_flexfield_code, context_code),
    constraint xxfnd_df_contexts_fk1 foreign key (descriptive_flexfield_code)
        references xxfnd_df_flexfields (descriptive_flexfield_code),
    constraint xxfnd_df_contexts_ck1 check (global_flag in ('Y','N')),
    constraint xxfnd_df_contexts_ck2 check (enabled_flag in ('Y','N')),
    constraint xxfnd_df_contexts_ck3 check (protected_flag in ('Y','N')),
    constraint xxfnd_df_contexts_ck4 check (global_flag = 'N' or context_code = 'GLOBAL')
)~') then
        xxfnd_ddl_pkg.run(q'~create unique index xxfnd_df_contexts_u1 on xxfnd_df_contexts (
    case when global_flag = 'Y' then descriptive_flexfield_code end)~');
        xxfnd_ddl_pkg.run(q'~comment on table  xxfnd_df_contexts is 'Contexts (FND_DESCR_FLEX_CONTEXTS). GLOBAL segments show on every row; other contexts show when ATTRIBUTE_CATEGORY matches.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_df_contexts.protected_flag is 'Y = seeded by the system; administrators cannot disable or delete it.'~');
    end if;
end;
/
-- One GLOBAL context per flexfield. Single-expression key: non-global rows are NULL and not indexed.
