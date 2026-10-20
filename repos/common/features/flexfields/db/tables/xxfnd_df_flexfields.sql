
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
--------------------------------------------------------------------------------
-- 10a Flexfield context rule and segment API name (release 92, UI issues 6 and 7). Checked steps on existing tables:
-- XXFND_DF_FLEXFIELDS.CONTEXT_RULE_TYPE (how ATTRIBUTE_CATEGORY is set, as in EBS / Fusion: GLOBAL only, from an
-- ATTRIBUTE of the row, from a FUNCTION, or chosen by the USER) and CONTEXT_RULE_FUNCTION; XXFND_DF_SEGMENTS.API_NAME.
-- Runs before 10/11 (their %ROWTYPE reads the new columns). A re-run changes nothing.
--------------------------------------------------------------------------------
declare
    l_new boolean;
    function has_column(p_table in varchar2, p_column in varchar2) return boolean is
        l_n pls_integer;
    begin
        select count(*) into l_n from user_tab_columns where table_name = p_table and column_name = p_column;
        return l_n > 0;
    end;
begin
    l_new := not has_column('XXFND_DF_FLEXFIELDS', 'CONTEXT_RULE_TYPE');
    xxfnd_ddl_pkg.add_column('XXFND_DF_FLEXFIELDS', 'CONTEXT_RULE_TYPE', q'~varchar2(20) default 'GLOBAL' not null~');
    xxfnd_ddl_pkg.add_column('XXFND_DF_FLEXFIELDS', 'CONTEXT_RULE_FUNCTION', 'varchar2(261)');
    xxfnd_ddl_pkg.add_constraint('XXFND_DF_FLEXFIELDS', 'XXFND_DF_FLEXFIELDS_CK4',
        q'~check (context_rule_type in ('GLOBAL','ATTRIBUTE','FUNCTION','USER'))~');
    if l_new then
        -- the rule of the existing flexfields, from their old settings
        execute immediate q'~update xxfnd_df_flexfields
            set context_rule_type = case when context_reference_column is not null then 'ATTRIBUTE'
                                         when context_user_selectable_flag = 'Y' then 'USER' else 'GLOBAL' end~';
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_df_flexfields.context_rule_type is 'Release 92: how the context (ATTRIBUTE_CATEGORY) is set on save - GLOBAL (default context only), ATTRIBUTE (the value of CONTEXT_REFERENCE_COLUMN, e.g. PARTY_TYPE or COUNTRY), FUNCTION (CONTEXT_RULE_FUNCTION(p_table_name, p_pk_value) returns it), USER (picked from a list).'~');
    end if;

    l_new := not has_column('XXFND_DF_SEGMENTS', 'API_NAME');
    xxfnd_ddl_pkg.add_column('XXFND_DF_SEGMENTS', 'API_NAME', 'varchar2(30)');
    if l_new then
        execute immediate q'~update xxfnd_df_segments set api_name = lower(segment_code) where api_name is null~';
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_df_segments.api_name is 'Release 92: the segment''s name in APIs, views and integrations (EBS end-user column name); the prompt is the display name.'~');
    end if;
    commit;
end;
/
