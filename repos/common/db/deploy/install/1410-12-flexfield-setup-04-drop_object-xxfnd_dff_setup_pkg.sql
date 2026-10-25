
-- release 80: the setup package merged into XXFND_DFF_PKG (old callers break on purpose: no wrappers); the reporting
-- views this schema created over other schemas' tables leave it (each application creates its own)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_DFF_SETUP_PKG', 'PACKAGE');
    for v in (select v.view_name from user_views v
               join xxfnd_df_flexfields f on f.table_name || '_DFV' = v.view_name
              where not exists (select 1 from user_tables t where t.table_name = f.table_name)) loop
        xxfnd_ddl_pkg.drop_object(v.view_name, 'VIEW');
    end loop;
end;
/
