

--------------------------------------------------------------------------------
-- Release 82: the merged packages are dropped (checked step; DDL and dependents kept in XXFND_DROPPED_OBJECTS).
-- Their callers use XXFND_WORKFLOW_PKG and XXFND_NOTIFY_PKG; old callers break on purpose (D15).
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.drop_object('XXFND_TASK_PKG', 'PACKAGE');
    xxfnd_ddl_pkg.drop_object('XXFND_WORKFLOW_SWITCH_PKG', 'PACKAGE');
    xxfnd_ddl_pkg.drop_object('XXFND_COMMUNICATION_PKG', 'PACKAGE');
end;
/
