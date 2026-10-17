
-- the packages merged into this one (old callers break on purpose: no wrappers)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_AUTH_PKG', 'PACKAGE');
    xxfnd_ddl_pkg.drop_object('XXFND_SECURITY_PKG', 'PACKAGE');
end;
/
