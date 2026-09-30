begin
    -- WHO columns and configuration audit, generated for every XXFND_/XXCMP_ table.
    xxfnd_util_pkg.create_all_who_triggers;
    xxfnd_audit_pkg.create_config_audit_triggers;
end;
/
