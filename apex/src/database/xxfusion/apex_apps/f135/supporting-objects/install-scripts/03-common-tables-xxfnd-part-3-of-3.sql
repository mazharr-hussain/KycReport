create table if not exists xxfnd_df_contexts_tl (
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
);

create table if not exists xxfnd_df_segments (
    descriptive_flexfield_code varchar2(60) not null,
    context_code           varchar2(80)   not null,
    segment_code           varchar2(30)   not null,
    column_name            varchar2(128)  not null,
    sequence_number        number(3)      not null,
    prompt                 varchar2(240)  not null,
    help_text              varchar2(1000),
    value_set_code         varchar2(60)   not null,
    required_flag          varchar2(1)    default 'N' not null,
    default_type           varchar2(20)   default 'NONE' not null,
    default_value          varchar2(4000),
    read_only_flag         varchar2(1)    default 'N' not null,
    display_flag           varchar2(1)    default 'Y' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_df_segments_pk primary key (descriptive_flexfield_code, context_code, segment_code),
    constraint xxfnd_df_segments_uk1 unique (descriptive_flexfield_code, context_code, column_name),
    constraint xxfnd_df_segments_uk2 unique (descriptive_flexfield_code, context_code, sequence_number),
    constraint xxfnd_df_segments_fk1 foreign key (descriptive_flexfield_code, context_code)
        references xxfnd_df_contexts (descriptive_flexfield_code, context_code),
    constraint xxfnd_df_segments_fk2 foreign key (value_set_code) references xxfnd_value_sets (value_set_code),
    constraint xxfnd_df_segments_ck1 check (required_flag in ('Y','N')),
    constraint xxfnd_df_segments_ck2 check (default_type in ('NONE','CONSTANT','SQL')),
    constraint xxfnd_df_segments_ck3 check (read_only_flag in ('Y','N')),
    constraint xxfnd_df_segments_ck4 check (display_flag in ('Y','N')),
    constraint xxfnd_df_segments_ck5 check (enabled_flag in ('Y','N')),
    constraint xxfnd_df_segments_ck6 check (default_type = 'NONE' or default_value is not null),
    constraint xxfnd_df_segments_ck7 check (regexp_like(column_name,
        '^ATTRIBUTE([1-9]|[12][0-9]|30)$|^ATTRIBUTE_NUMBER([1-9]|10)$|^ATTRIBUTE_DATE([1-9]|10)$|^ATTRIBUTE_TIMESTAMP[1-5]$'))
);
create index if not exists xxfnd_df_segments_n1 on xxfnd_df_segments (value_set_code);
comment on table  xxfnd_df_segments is 'Segments (FND_DESCR_FLEX_COLUMN_USAGES): maps a field to one reserved column. XXFND_DFF_PKG also checks that the column family matches the value set format and that GLOBAL columns are not reused by other contexts.';
comment on column xxfnd_df_segments.default_value is 'CONSTANT: the literal. SQL: a query returning one value; may reference :CONTEXT_CODE.';

create table if not exists xxfnd_df_segments_tl (
    descriptive_flexfield_code varchar2(60) not null,
    context_code           varchar2(80)   not null,
    segment_code           varchar2(30)   not null,
    language_code          varchar2(10)   not null,
    prompt                 varchar2(240)  not null,
    help_text              varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_df_segments_tl_pk primary key (descriptive_flexfield_code, context_code, segment_code, language_code),
    constraint xxfnd_df_segments_tl_fk1 foreign key (descriptive_flexfield_code, context_code, segment_code)
        references xxfnd_df_segments (descriptive_flexfield_code, context_code, segment_code) on delete cascade
);
