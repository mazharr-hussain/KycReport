
begin
    xxfnd_ddl_pkg.ensure_table('XXFND_LOOKUP_VALUES_TL', q'~create table xxfnd_lookup_values_tl (
    lookup_type            varchar2(30)   not null,
    lookup_code            varchar2(30)   not null,
    language_code          varchar2(10)   not null,
    meaning                varchar2(200)  not null,
    description            varchar2(500),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_lookup_values_tl_pk primary key (lookup_type, lookup_code, language_code),
    constraint xxfnd_lookup_values_tl_fk1 foreign key (lookup_type, lookup_code)
        references xxfnd_lookup_values (lookup_type, lookup_code) on delete cascade
)~');
end;
/

begin
    xxfnd_ddl_pkg.ensure_table('XXFND_NOTIFICATION_TEMPLATES_TL', q'~create table xxfnd_notification_templates_tl (
    template_code          varchar2(50)   not null,
    language_code          varchar2(10)   not null,
    subject                varchar2(500)  not null,
    body_html              clob           not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_notif_templates_tl_pk primary key (template_code, language_code),
    constraint xxfnd_notif_templates_tl_fk1 foreign key (template_code)
        references xxfnd_notification_templates (template_code) on delete cascade
)~');
end;
/

begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DOCUMENT_ENTITIES_TL', q'~create table xxfnd_document_entities_tl (
    entity_name            varchar2(60)   not null,
    language_code          varchar2(10)   not null,
    user_entity_name       varchar2(240)  not null,
    description            varchar2(500),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_entities_tl_pk primary key (entity_name, language_code),
    constraint xxfnd_doc_entities_tl_fk1 foreign key (entity_name)
        references xxfnd_document_entities (entity_name) on delete cascade
)~');
end;
/

begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DOCUMENT_CATEGORIES_TL', q'~create table xxfnd_document_categories_tl (
    category_code          varchar2(30)   not null,
    language_code          varchar2(10)   not null,
    category_name          varchar2(240)  not null,
    description            varchar2(500),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_categories_tl_pk primary key (category_code, language_code),
    constraint xxfnd_doc_categories_tl_fk1 foreign key (category_code)
        references xxfnd_document_categories (category_code) on delete cascade
)~');
end;
/

begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DOCUMENTS_TL', q'~create table xxfnd_documents_tl (
    document_id            number         not null,
    language_code          varchar2(10)   not null,
    title                  varchar2(400),
    description            varchar2(2000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_documents_tl_pk primary key (document_id, language_code),
    constraint xxfnd_documents_tl_fk1 foreign key (document_id) references xxfnd_documents (document_id) on delete cascade
)~');
end;
/

begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DF_FLEXFIELDS_TL', q'~create table xxfnd_df_flexfields_tl (
    descriptive_flexfield_code varchar2(60) not null,
    language_code          varchar2(10)   not null,
    flexfield_name         varchar2(240)  not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_df_flexfields_tl_pk primary key (descriptive_flexfield_code, language_code),
    constraint xxfnd_df_flexfields_tl_fk1 foreign key (descriptive_flexfield_code)
        references xxfnd_df_flexfields (descriptive_flexfield_code) on delete cascade
)~');
end;
/
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

begin
    xxfnd_ddl_pkg.ensure_table('XXFND_DF_SEGMENTS_TL', q'~create table xxfnd_df_segments_tl (
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
)~');
end;
/
