
-- release 80: XXFND_ADMIN_APPLICATIONS_V was not used by any page or package: dropped (checked, DDL recorded)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_ADMIN_APPLICATIONS_V', 'VIEW');
end;
/

