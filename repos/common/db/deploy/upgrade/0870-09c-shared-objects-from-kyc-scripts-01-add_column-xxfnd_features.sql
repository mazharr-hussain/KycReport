--------------------------------------------------------------------------------
-- 09c Shared objects formerly created by KYC scripts (release 54). COMMON only.
--   The shared XXFND_ objects live only in XXFUSION, so their DDL runs there: the admin console columns,
--   index and view (from 18c) and the maker-checker trigger of the integration purposes (from 16).
-- Idempotent.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_FEATURES',      'HOME_PAGE_ID', 'number');
    xxfnd_ddl_pkg.add_column('XXFND_FEATURES',      'ICON_CSS',     'varchar2(60)');
    xxfnd_ddl_pkg.add_column('XXFND_FEATURE_PAGES', 'TAB_LABEL',    'varchar2(60)');
    xxfnd_ddl_pkg.add_column('XXFND_FEATURE_PAGES', 'TAB_SEQUENCE', 'number');
    -- the audit trigger lists the columns: regenerate it for the new ones
    xxfnd_schema_pkg.create_audit_trigger('XXFND_FEATURE_PAGES');
end;
/
-- one rule per role, table, rule type, column and values (release 79: rules without a role are assigned to users and
-- roles, so two department rules on the same column differ by their values; U1 without the values is replaced)
begin
    xxfnd_ddl_pkg.drop_index('XXFND_DATA_SECURITY_RULES_U1');
    xxfnd_ddl_pkg.ensure_index('XXFND_DATA_SECURITY_RULES_U2', q'~create unique index xxfnd_data_security_rules_u2
        on xxfnd_data_security_rules (nvl(role_code, '#'), table_name, rule_type, nvl(column_name, '#'),
                                      standard_hash(nvl(value_list, '#')))~');
end;
/

comment on column xxfnd_features.home_page_id is 'Page opened by the feature''s menu entry.';
comment on column xxfnd_feature_pages.tab_label is 'Tab shown on every list page of the same feature; null = not a tab (forms, dialogs).';
