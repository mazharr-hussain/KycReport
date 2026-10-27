--------------------------------------------------------------------------------
-- 99 Sharing with the applications - last (release 87, C11). COMMON only (XXFUSION). The LAST script of every COMMON
--   install and upgrade: whatever an earlier script created is granted to every registered application's schema
--   (XXFND_SHARE_PKG.GRANT_TO_APPLICATIONS), the onboarding entry to every schema of the workspace (GRANT_ONBOARDING),
--   and anything left invalid is compiled again. Later releases add their scripts before this one.
-- Idempotent: a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_share_pkg.grant_to_applications;
    xxfnd_share_pkg.grant_onboarding;
end;
/

begin
    dbms_utility.compile_schema(schema => user, compile_all => false);
end;
/
