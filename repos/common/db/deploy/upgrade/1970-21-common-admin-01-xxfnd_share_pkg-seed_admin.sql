--------------------------------------------------------------------------------
-- 21 COMMON administration seed (release 61). Installed by the COMMON application only (XXFUSION), after 20.
--   The shared setup screens run in the COMMON application for every registered application (16i: scope):
--   1. The admin features and their privileges - the same codes the business applications use, so a privilege a
--      user already holds works on the COMMON screen too. Created only when missing (an application's own rows,
--      once moved here, are kept).
--   2. Which COMMON page belongs to which feature (XXFND_FEATURE_PAGES, app alias COMMON), with the tabs.
--   3. The Common Administrator (COMMON_ADMIN) holds every admin privilege.
-- Idempotent: rows are created once; administrators maintain them on the screens. The seed is
--   XXFND_SHARE_PKG.SEED_ADMIN (script 19c), so the move of an application's shared data re-applies it.
--------------------------------------------------------------------------------
begin
    xxfnd_share_pkg.seed_admin;
end;
/
