
-- 5. the retired endpoints: trigger, the foreign keys to the table, the table (data copied in step 2)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_INT_ENDPOINTS_RO', 'TRIGGER');
    xxfnd_ddl_pkg.drop_constraint('XXFND_STORAGE_CONFIG', 'XXFND_STORAGE_CONFIG_FK3');
    xxfnd_ddl_pkg.drop_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_FK1');
    xxfnd_ddl_pkg.drop_constraint('XXFND_TRANSMISSIONS', 'XXFND_TRANSMISSIONS_FK1');
    xxfnd_ddl_pkg.drop_object('XXFND_INTEGRATION_ENDPOINTS', 'TABLE', p_retired_table => true);
    delete from xxfnd_config_tables where table_name = 'XXFND_INTEGRATION_ENDPOINTS';
    commit;
end;
/
