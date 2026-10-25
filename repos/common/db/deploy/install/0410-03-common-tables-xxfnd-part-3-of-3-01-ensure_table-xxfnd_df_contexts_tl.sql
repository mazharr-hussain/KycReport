begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DF_CONTEXTS_TL', q'~create table xxfnd_df_contexts_tl (
    descriptive_flexfield_code varchar2(60) not null,
    context_code           varchar2(80)   not null,
    language_code          varchar2(10)   not null,
    context_name           varchar2(240)  not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_df_contexts_tl_pk primary key (descriptive_flexfield_code, context_code, language_code),
    constraint xxfnd_df_contexts_tl_fk1 foreign key (descriptive_flexfield_code, context_code)
        references xxfnd_df_contexts (descriptive_flexfield_code, context_code) on delete cascade
)~');
end;
/
