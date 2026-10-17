
-- release 80: the packages merged into XXFND_APPLICATION_PKG (09d), dropped once every trigger and policy uses it
-- (16i: scope policies and _SC triggers; above: the _LV triggers). Old callers break on purpose: no wrappers.
begin
    xxfnd_ddl_pkg.drop_object('XXFND_SETUP_TYPE_PKG', 'PACKAGE');
    xxfnd_ddl_pkg.drop_object('XXFND_ADMIN_SCOPE_PKG', 'PACKAGE');
    xxfnd_ddl_pkg.drop_object('XXFND_APP_FUNCTION_PKG', 'PACKAGE');
end;
/
