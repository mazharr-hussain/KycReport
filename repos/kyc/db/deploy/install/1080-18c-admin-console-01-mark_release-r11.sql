--------------------------------------------------------------------------------
-- C03 Admin console (release R11)
--   Release 54: the columns, index and view of the admin console are shared objects (COMMON 09c).
--   Release 87: the landing pages, icons and tabs of the KYC features are registered in COMMON by 18h; this script
--   only records the release.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.mark_release('R11', 'Release 11: admin console (feature landing pages, tabs, security screens)');
    commit;
end;
/
