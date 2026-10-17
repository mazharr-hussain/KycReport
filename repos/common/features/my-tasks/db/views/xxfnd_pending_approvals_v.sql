
-- release 82: XXFND_PENDING_APPROVALS_V was used by nothing; dropped (checked step, DDL kept in XXFND_DROPPED_OBJECTS)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_PENDING_APPROVALS_V', 'VIEW');
end;
/
