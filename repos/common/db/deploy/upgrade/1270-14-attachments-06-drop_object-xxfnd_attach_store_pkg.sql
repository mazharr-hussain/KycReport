
-- release 81: the store transport merged into this package (old callers break on purpose: no wrappers)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_ATTACH_STORE_PKG', 'PACKAGE');
end;
/
