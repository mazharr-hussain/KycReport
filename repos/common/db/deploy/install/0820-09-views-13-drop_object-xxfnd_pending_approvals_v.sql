comment on table xxfnd_config_changes_v is 'Maker-checker changes waiting for approval, one row per CONFIG_CHANGE approval task (DETAIL_PK), from every application.';

-- release 82: XXFND_PENDING_APPROVALS_V was used by nothing; dropped (checked step, DDL kept in XXFND_DROPPED_OBJECTS)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_PENDING_APPROVALS_V', 'VIEW');
end;
/
