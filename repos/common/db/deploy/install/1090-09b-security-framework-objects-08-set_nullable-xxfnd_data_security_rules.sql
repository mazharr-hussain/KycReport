begin
    xxfnd_ddl_pkg.set_nullable('XXFND_DATA_SECURITY_RULES', 'ROLE_CODE');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_data_security_rules.role_code is 'Until release 78 the only role of the rule; since release 79 the rule is assigned in XXFND_DATA_RULE_ASSIGNMENTS (this role became its first assignment).'~');

end;
/
