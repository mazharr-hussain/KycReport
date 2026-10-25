
begin
    for t in (select table_name from user_tables
               where table_name in ('XXFND_FEATURES','XXFND_PRIVILEGES','XXFND_FEATURE_PAGES',
                                    'XXFND_ROLE_PRIVILEGES','XXFND_DATA_SECURITY_RULES',
                                    'XXFND_DATA_RULE_ASSIGNMENTS')) loop
        xxfnd_schema_pkg.create_who_trigger(t.table_name);
    end loop;
    -- Security configuration is audited like every other setup table.
    xxfnd_schema_pkg.create_audit_trigger('XXFND_ROLE_PRIVILEGES');
    xxfnd_schema_pkg.create_audit_trigger('XXFND_DATA_SECURITY_RULES');
    xxfnd_schema_pkg.create_audit_trigger('XXFND_DATA_RULE_ASSIGNMENTS');
    xxfnd_schema_pkg.create_audit_trigger('XXFND_FEATURE_PAGES');
end;
/
