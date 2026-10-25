--------------------------------------------------------------------------------
-- 20 COMMON application seed (release 49). Installed by the COMMON application only.
--   The COMMON application (code and alias COMMON) runs on the XXFUSION schema and holds what every
--   application shares: security, flexfield and attachment setup, workflow. Its own access:
--     role    COMMON_ADMIN  - administers the shared setup
--     feature COMMON_HOME   - the home page (page 1)
--   The developer installing the application (or the workspace administrators, when installed without
--   an APEX session) becomes the first COMMON_ADMIN.
-- Idempotent: rows are inserted once; administrators maintain them on the setup screens.
--------------------------------------------------------------------------------
-- release 54: the seed is XXFND_SHARE_PKG.SEED_COMMON (script 19c), so the move of an application's shared data
-- (import_schema) can re-apply it.
begin
    xxfnd_share_pkg.seed_common;
    commit;
end;
/
