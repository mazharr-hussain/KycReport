begin
    -- WHO columns and configuration audit for the XXFND_/XXCMP_ tables of the running schema (release 54: xxfnd_schema_pkg, invoker rights).
    xxfnd_schema_pkg.create_all_who_triggers;
    xxfnd_schema_pkg.create_config_audit_triggers;
end;
/
