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
create table xxfnd_lookup_types (
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
);
comment on table  xxfnd_lookup_types is 'Lookup type header (FND_LOOKUP_TYPES). APPLICATION_CODE null = shared by every application.';
comment on column xxfnd_lookup_types.customization_level is 'S = system (values locked), E = extensible (values may be added), U = user (fully editable).';

create table xxfnd_lookup_values (
    lookup_type            varchar2(30)   not null,
    lookup_code            varchar2(30)   not null,
    meaning                varchar2(200)  not null,
    description            varchar2(500),
    tag                    varchar2(150),
    parent_lookup_type     varchar2(30),
    parent_lookup_code     varchar2(30),
    display_sequence       number,
    enabled_flag           varchar2(1)    default 'Y' not null,
    start_date_active      date           default trunc(sysdate) not null,
    end_date_active        date,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_lookup_values_pk primary key (lookup_type, lookup_code),
    constraint xxfnd_lookup_values_fk1 foreign key (lookup_type) references xxfnd_lookup_types (lookup_type),
    constraint xxfnd_lookup_values_fk2 foreign key (parent_lookup_type, parent_lookup_code)
        references xxfnd_lookup_values (lookup_type, lookup_code),
    constraint xxfnd_lookup_values_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_lookup_values_ck2 check (end_date_active is null or end_date_active >= start_date_active)
);
create index xxfnd_lookup_values_n1 on xxfnd_lookup_values (parent_lookup_type, parent_lookup_code);
comment on table  xxfnd_lookup_values is 'Lookup values (FND_LOOKUP_VALUES). Parent columns support dependent (cascading) values.';
comment on column xxfnd_lookup_values.tag is 'One extra attribute for a value, e.g. a jurisdiction''s UBO threshold. Needs more than one? Use a dedicated table.';

create table xxfnd_lookup_values_tl (
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
);

--==============================================================================
-- 0.0  IDENTITY AND ACCESS
--==============================================================================
create table xxfnd_employees (
    employee_id            number generated by default on null as identity,
    source_type            varchar2(20)   default 'LOCAL' not null,
    fusion_person_id       number,
    fusion_person_number   varchar2(30),
    user_name              varchar2(255)  not null,
    full_name              varchar2(240)  not null,
    email_address          varchar2(320)  not null,
    department_name        varchar2(240),
    job_title              varchar2(240),
    last_sync_date         timestamp,
    enabled_flag           varchar2(1)    default 'Y' not null,
    start_date_active      date           default trunc(sysdate) not null,
    end_date_active        date,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_employees_pk primary key (employee_id),
    constraint xxfnd_employees_uk1 unique (user_name),
    constraint xxfnd_employees_uk2 unique (email_address),
    constraint xxfnd_employees_ck1 check (source_type in ('FUSION','LOCAL')),
    constraint xxfnd_employees_ck2 check (
        (source_type = 'FUSION' and fusion_person_id is not null) or
        (source_type = 'LOCAL'  and fusion_person_id is null)),
    constraint xxfnd_employees_ck3 check (enabled_flag in ('Y','N')),
    constraint xxfnd_employees_ck4 check (user_name = upper(user_name))
);
create unique index xxfnd_employees_u3 on xxfnd_employees (fusion_person_id);
comment on table  xxfnd_employees is 'One row per person. FUSION rows are maintained by the Fusion HCM sync and are read-only in the application; LOCAL rows are maintained by an administrator.';
comment on column xxfnd_employees.user_name is 'Matches APP_USER after sign-in (upper case). This is how a session resolves to a person.';

create table xxfnd_roles (
    role_code              varchar2(30)   not null,
    application_code       varchar2(30)   not null,
    role_name              varchar2(200)  not null,
    description            varchar2(500),
    view_sensitive_flag    varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_roles_pk primary key (role_code),
    constraint xxfnd_roles_ck1 check (view_sensitive_flag in ('Y','N')),
    constraint xxfnd_roles_ck2 check (enabled_flag in ('Y','N'))
);
create index xxfnd_roles_n1 on xxfnd_roles (application_code);
comment on table xxfnd_roles is 'Application roles. Enforced by APEX authorization schemes that call XXFND_SECURITY_PKG.';

create table xxfnd_user_roles (
    user_role_id           number generated by default on null as identity,
    employee_id            number         not null,
    role_code              varchar2(30)   not null,
    start_date_active      date           default trunc(sysdate) not null,
    end_date_active        date,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_user_roles_pk primary key (user_role_id),
    constraint xxfnd_user_roles_fk1 foreign key (employee_id) references xxfnd_employees (employee_id),
    constraint xxfnd_user_roles_fk2 foreign key (role_code) references xxfnd_roles (role_code),
    constraint xxfnd_user_roles_ck1 check (enabled_flag in ('Y','N')),
    constraint xxfnd_user_roles_ck2 check (end_date_active is null or end_date_active >= start_date_active)
);
create index xxfnd_user_roles_n1 on xxfnd_user_roles (employee_id);
create index xxfnd_user_roles_n2 on xxfnd_user_roles (role_code);
-- One open-ended grant per person and role; closed history rows may repeat.
-- Every key column is wrapped in the CASE: rows outside the condition have an all-NULL key and are not indexed.
create unique index xxfnd_user_roles_u1 on xxfnd_user_roles (
    case when end_date_active is null then employee_id end,
    case when end_date_active is null then role_code end);

create table xxfnd_sod_rules (
    sod_rule_id            number generated by default on null as identity,
    role_code_1            varchar2(30)   not null,
    role_code_2            varchar2(30)   not null,
    conflict_scope         varchar2(30)   not null,
    description            varchar2(500),
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_sod_rules_pk primary key (sod_rule_id),
    constraint xxfnd_sod_rules_fk1 foreign key (role_code_1) references xxfnd_roles (role_code),
    constraint xxfnd_sod_rules_fk2 foreign key (role_code_2) references xxfnd_roles (role_code),
    constraint xxfnd_sod_rules_uk1 unique (role_code_1, role_code_2, conflict_scope),
    constraint xxfnd_sod_rules_ck1 check (role_code_1 < role_code_2),
    constraint xxfnd_sod_rules_ck2 check (enabled_flag in ('Y','N'))
);
comment on table  xxfnd_sod_rules is 'Role pairs that one person may not both exercise within CONFLICT_SCOPE. Stored in canonical order so a pair cannot be entered twice.';
comment on column xxfnd_sod_rules.conflict_scope is 'Lookup SOD_SCOPE, e.g. SAME_RECORD (same case) or GLOBAL (never both roles).';

--==============================================================================
-- 0.0  NOTIFICATION TEMPLATES, AUDIT, RETENTION
--==============================================================================
create table xxfnd_notification_templates (
    template_code          varchar2(50)   not null,
    application_code       varchar2(30),
    subject                varchar2(500)  not null,
    body_html              clob           not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_notif_templates_pk primary key (template_code),
    constraint xxfnd_notif_templates_ck1 check (enabled_flag in ('Y','N'))
);
comment on table xxfnd_notification_templates is 'Wording of every system email and alert. Placeholders use #TOKEN# syntax and are replaced at send time.';

create table xxfnd_notification_templates_tl (
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
);

create table xxfnd_audit_log (
    audit_log_id           number generated by default on null as identity,
    table_name             varchar2(128)  not null,
    pk_value               varchar2(400)  not null,
    action_code            varchar2(1)    not null,
    column_name            varchar2(128),
    old_value              varchar2(4000),
    new_value              varchar2(4000),
    change_reason          varchar2(1000),
    changed_by             varchar2(255)  not null,
    changed_date           timestamp      default systimestamp not null,
    constraint xxfnd_audit_log_pk primary key (audit_log_id),
    constraint xxfnd_audit_log_ck1 check (action_code in ('I','U','D'))
);
create index xxfnd_audit_log_n1 on xxfnd_audit_log (table_name, pk_value);
create index xxfnd_audit_log_n2 on xxfnd_audit_log (changed_date);
comment on table xxfnd_audit_log is 'Append-only change log for configuration tables, written by triggers that XXFND_AUDIT_PKG generates. Rows are never updated, so there are no WHO columns.';

create table xxfnd_retention_policies (
    retention_policy_id    number generated by default on null as identity,
    table_name             varchar2(128)  not null,
    jurisdiction           varchar2(30),
    retention_years        number(3)      not null,
    action_at_expiry       varchar2(30)   not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_retention_policies_pk primary key (retention_policy_id),
    constraint xxfnd_retention_policies_ck1 check (action_at_expiry in ('ARCHIVE','PURGE','FLAG_FOR_REVIEW')),
    constraint xxfnd_retention_policies_ck2 check (retention_years > 0),
    constraint xxfnd_retention_policies_ck3 check (enabled_flag in ('Y','N'))
);
create unique index xxfnd_retention_policies_u1 on xxfnd_retention_policies (table_name, nvl(jurisdiction, '#'));

--==============================================================================
-- 0.4  INTEGRATION HUB  (created before attachments, which reference endpoints)
--==============================================================================
create table xxfnd_integration_endpoints (
    endpoint_code          varchar2(30)   not null,
    endpoint_name          varchar2(200)  not null,
    endpoint_type          varchar2(30)   not null,
    base_url               varchar2(1000) not null,
    web_credential_static_id varchar2(255),
    oauth_token_url        varchar2(1000),
    oauth_scope            varchar2(1000),
    status_code            varchar2(20)   default 'REGISTERED' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_int_endpoints_pk primary key (endpoint_code),
    constraint xxfnd_int_endpoints_ck1 check (status_code in ('REGISTERED','ACTIVE','INACTIVE'))
);
comment on column xxfnd_integration_endpoints.oauth_token_url is 'OAuth2 client-credentials token URL (not a secret), e.g. https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token for SharePoint via Microsoft Graph.';
comment on table  xxfnd_integration_endpoints is 'Non-Oracle external systems. Secrets live only in APEX Web Credentials (Shared Components); this table stores the credential static ID. Oracle Fusion uses APEX''s native Fusion integration instead.';
comment on column xxfnd_integration_endpoints.endpoint_type is 'Lookup ENDPOINT_TYPE: UCM, SHAREPOINT, SCREENING_PROVIDER, REGISTRY_PROVIDER, DOC_AUTH_PROVIDER, OTHER.';

create table xxfnd_integration_purposes (
    purpose_code           varchar2(30)   not null,
    application_code       varchar2(30),
    purpose_name           varchar2(200)  not null,
    endpoint_code          varchar2(30),
    capture_method         varchar2(20)   default 'MANUAL' not null,
    approval_status        varchar2(20)   default 'DRAFT' not null,
    approved_by            varchar2(255),
    approved_date          timestamp,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_int_purposes_pk primary key (purpose_code),
    constraint xxfnd_int_purposes_fk1 foreign key (endpoint_code) references xxfnd_integration_endpoints (endpoint_code),
    constraint xxfnd_int_purposes_ck1 check (capture_method in ('MANUAL','API')),
    constraint xxfnd_int_purposes_ck2 check (approval_status in ('DRAFT','PENDING_APPROVAL','APPROVED','REJECTED')),
    constraint xxfnd_int_purposes_ck3 check (capture_method = 'MANUAL' or endpoint_code is not null)
);
comment on table xxfnd_integration_purposes is 'Which endpoint serves each business purpose, and whether it runs manually or by API. Changes take effect only after a second person approves them.';

create table xxfnd_transmissions (
    transmission_id        number generated by default on null as identity,
    endpoint_code          varchar2(30)   not null,
    purpose_code           varchar2(30)   not null,
    entity_name            varchar2(60),
    pk1_value              varchar2(150),
    http_method            varchar2(10)   not null,
    request_url            varchar2(4000) not null,
    request_payload        clob,
    response_status_code   number(3),
    response_payload       clob,
    status_code            varchar2(20)   default 'PENDING' not null,
    retry_count            number(3)      default 0 not null,
    error_message          varchar2(4000),
    sent_date              timestamp      default systimestamp not null,
    responded_date         timestamp,
    created_by             varchar2(255)  not null,
    constraint xxfnd_transmissions_pk primary key (transmission_id),
    constraint xxfnd_transmissions_fk1 foreign key (endpoint_code) references xxfnd_integration_endpoints (endpoint_code),
    constraint xxfnd_transmissions_fk2 foreign key (purpose_code) references xxfnd_integration_purposes (purpose_code),
    constraint xxfnd_transmissions_ck1 check (status_code in ('PENDING','SUCCESS','FAILED','RETRYING'))
);
create index xxfnd_transmissions_n1 on xxfnd_transmissions (entity_name, pk1_value);
create index xxfnd_transmissions_n2 on xxfnd_transmissions (status_code, sent_date);
comment on table xxfnd_transmissions is 'Business-level log of every outbound call, tied to the record it served. Binary payloads are not stored; REQUEST_PAYLOAD holds metadata only for file uploads.';

--==============================================================================
-- 0.1  ATTACHMENTS  (EBS: FND_DOCUMENT_ENTITIES, FND_ATTACHMENT_FUNCTIONS,
--      FND_ATTACHMENT_BLOCKS, FND_ATTACHMENT_BLK_ENTITIES, FND_DOC_CATEGORY_USAGES,
--      FND_DOCUMENT_CATEGORIES, FND_DOCUMENTS, FND_ATTACHED_DOCUMENTS)
--==============================================================================
create table xxfnd_document_entities (
    entity_name            varchar2(60)   not null,
    application_code       varchar2(30),
    table_name             varchar2(128)  not null,
    pk1_column             varchar2(128)  not null,
    pk2_column             varchar2(128),
    pk3_column             varchar2(128),
    pk4_column             varchar2(128),
    pk5_column             varchar2(128),
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_entities_pk primary key (entity_name),
    constraint xxfnd_doc_entities_ck1 check (enabled_flag in ('Y','N'))
);
comment on table xxfnd_document_entities is 'Registered attachable entities (FND_DOCUMENT_ENTITIES). Gives ATTACHED_DOCUMENTS.ENTITY_NAME a real foreign key.';

create table xxfnd_document_entities_tl (
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
);

create table xxfnd_document_categories (
    category_code          varchar2(30)   not null,
    application_code       varchar2(30),
    category_name          varchar2(240)  not null,
    description            varchar2(500),
    default_datatype_code  varchar2(30)   default 'FILE' not null,
    has_expiry_flag        varchar2(1)    default 'N' not null,
    max_age_days           number(5),
    enabled_flag           varchar2(1)    default 'Y' not null,
    start_date_active      date           default trunc(sysdate) not null,
    end_date_active        date,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_categories_pk primary key (category_code),
    constraint xxfnd_doc_categories_ck1 check (default_datatype_code in ('FILE','SHORT_TEXT','LONG_TEXT','WEB_PAGE')),
    constraint xxfnd_doc_categories_ck2 check (has_expiry_flag in ('Y','N')),
    constraint xxfnd_doc_categories_ck3 check (enabled_flag in ('Y','N')),
    constraint xxfnd_doc_categories_ck4 check (max_age_days is null or max_age_days > 0)
);
comment on column xxfnd_document_categories.has_expiry_flag is 'Y = the document itself expires (passport, licence); an expiry date is required on upload.';
comment on column xxfnd_document_categories.max_age_days is 'How recent the document must be when submitted (e.g. utility bill within 90 days). Separate from expiry.';

create table xxfnd_document_categories_tl (
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
);

create table xxfnd_attachment_functions (
    function_code          varchar2(60)   not null,
    application_code       varchar2(30),
    function_name          varchar2(240)  not null,
    apex_app_alias         varchar2(255)  not null,
    apex_page_id           number         not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_att_functions_pk primary key (function_code),
    constraint xxfnd_att_functions_uk1 unique (apex_app_alias, apex_page_id),
    constraint xxfnd_att_functions_ck1 check (enabled_flag in ('Y','N'))
);
comment on table  xxfnd_attachment_functions is 'An APEX page that shows attachments (FND_ATTACHMENT_FUNCTIONS). Keyed by application alias, which stays stable across imports; the numeric application ID does not.';

create table xxfnd_attachment_blocks (
    function_code          varchar2(60)   not null,
    block_code             varchar2(60)   not null,
    region_static_id       varchar2(255)  not null,
    block_name             varchar2(240),
    display_sequence       number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_att_blocks_pk primary key (function_code, block_code),
    constraint xxfnd_att_blocks_fk1 foreign key (function_code)
        references xxfnd_attachment_functions (function_code) on delete cascade,
    constraint xxfnd_att_blocks_uk1 unique (function_code, region_static_id)
);
comment on table xxfnd_attachment_blocks is 'A region on the page (FND_ATTACHMENT_BLOCKS), identified by its static ID.';

create table xxfnd_attachment_blk_entities (
    function_code          varchar2(60)   not null,
    block_code             varchar2(60)   not null,
    entity_name            varchar2(60)   not null,
    pk1_page_item          varchar2(255)  not null,
    pk2_page_item          varchar2(255),
    pk3_page_item          varchar2(255),
    pk4_page_item          varchar2(255),
    pk5_page_item          varchar2(255),
    insert_allowed_flag    varchar2(1)    default 'Y' not null,
    update_allowed_flag    varchar2(1)    default 'Y' not null,
    delete_allowed_flag    varchar2(1)    default 'N' not null,
    display_sequence       number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_att_blk_entities_pk primary key (function_code, block_code, entity_name),
    constraint xxfnd_att_blk_entities_fk1 foreign key (function_code, block_code)
        references xxfnd_attachment_blocks (function_code, block_code) on delete cascade,
    constraint xxfnd_att_blk_entities_fk2 foreign key (entity_name) references xxfnd_document_entities (entity_name),
    constraint xxfnd_att_blk_entities_ck1 check (insert_allowed_flag in ('Y','N')),
    constraint xxfnd_att_blk_entities_ck2 check (update_allowed_flag in ('Y','N')),
    constraint xxfnd_att_blk_entities_ck3 check (delete_allowed_flag in ('Y','N'))
);
comment on table xxfnd_attachment_blk_entities is 'Which entity a region attaches to, which page items supply PK1-PK5, and what the user may do (FND_ATTACHMENT_BLK_ENTITIES).';

create table xxfnd_doc_category_usages (
    function_code          varchar2(60)   not null,
    category_code          varchar2(30)   not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_doc_category_usages_pk primary key (function_code, category_code),
    constraint xxfnd_doc_category_usages_fk1 foreign key (function_code)
        references xxfnd_attachment_functions (function_code) on delete cascade,
    constraint xxfnd_doc_category_usages_fk2 foreign key (category_code) references xxfnd_document_categories (category_code),
    constraint xxfnd_doc_category_usages_ck1 check (enabled_flag in ('Y','N'))
);
comment on table xxfnd_doc_category_usages is 'Categories a page may offer (FND_DOC_CATEGORY_USAGES). A page with no rows here offers every enabled category.';
