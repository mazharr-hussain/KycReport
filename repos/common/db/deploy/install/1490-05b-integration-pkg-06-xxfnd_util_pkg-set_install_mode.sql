
-- release 86: the servers are configuration - audited like the other setup tables
begin
    xxfnd_util_pkg.set_install_mode(true);
    merge into xxfnd_config_tables t using (select 'XXFND_SERVERS' table_name from dual) s
       on (t.table_name = s.table_name)
     when not matched then insert (table_name, application_id, audit_flag, created_by, creation_date, last_updated_by, last_update_date)
                           values (s.table_name, (select application_id from xxfnd_applications where application_code = 'COMMON'),
                                   'Y', 'INSTALL', systimestamp, 'INSTALL', systimestamp);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
    xxfnd_audit_pkg.create_audit_trigger('XXFND_SERVERS');
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
