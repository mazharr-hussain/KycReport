--------------------------------------------------------------------------------
-- C02 Security framework - seed (release R10).
--   Release 87: the KYC features, privileges, pages and first-install grants are registered in COMMON by 18h
--   (COMMON's registration routines); this script only records the release.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.mark_release('R10', 'Release 10: security framework (features, privileges, data security)');
    commit;
end;
/
