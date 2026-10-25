
begin
    xxfnd_util_pkg.create_who_trigger('XXFND_TASK_SETTINGS');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_TASK_SETTINGS');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_WF_DELEGATIONS');
end;
/
