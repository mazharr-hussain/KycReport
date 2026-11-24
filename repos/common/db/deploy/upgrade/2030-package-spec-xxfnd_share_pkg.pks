--------------------------------------------------------------------------------
-- 19c Sharing with the application schemas (release 54). COMMON only.
--   The shared XXFND_ objects (release 102: and the XXHR_ HR tables) exist only here (XXFUSION). Every application schema (XXFND_APPLICATIONS.SCHEMA_NAME,
--   e.g. KYC = XXCUS) gets grants on them and reaches them through synonyms, created by its own install
--   (KYC script 03). XXFND_SCHEMA_RELEASES and XXFND_DDL_PKG stay local to each schema (deployment tracking).
--   XXFND_SHARE_PKG:
--     grant_to / grant_to_applications - the grants (re-run on every install and upgrade: new objects too)
--     import_schema - one-time move of an application schema's own copy of the shared data into XXFUSION
--     seed_common   - the COMMON application's own access (role COMMON_ADMIN, feature COMMON_HOME, first admin)
--     grant_onboarding (release 87) - EXECUTE on XXFND_ONBOARD_PKG to the workspace's schemas; the grants run last
--       (script 99, C11)
--------------------------------------------------------------------------------
create or replace package xxfnd_share_pkg authid definer as
    -- Shared objects that stay local to each schema (never granted, never replaced by synonyms).
    function is_local(p_object_name in varchar2) return boolean;
    -- Tables: SELECT (with grant option, for the application's views) and REFERENCES (release 88: no INSERT, UPDATE or
    -- DELETE - data changes only through the COMMON routines; an earlier grant is taken back);
    -- views: SELECT; sequences: SELECT; packages, types, procedures, functions: EXECUTE.
    procedure grant_to(p_schema in varchar2);
    -- grant_to for the schema of every registered application that exists in this database.
    procedure grant_to_applications;
    -- release 87: EXECUTE on XXFND_ONBOARD_PKG to every schema of COMMON's workspace, so an application's own install
    -- can register it (generic script 00c); everything else is granted only once the application is registered.
    procedure grant_onboarding;
    -- One-time move: replaces the shared data here with the copy kept so far in p_schema (same keys, so the
    -- application's rows that refer to them stay valid), then re-applies seed_common. Every column of p_schema's
    -- tables must exist here, otherwise nothing is changed (-20140). Called by the application's install
    -- (KYC script 03) after it granted SELECT on its copy; recorded as release MOVE_<schema>, so it runs once.
    procedure import_schema(p_schema in varchar2);
    -- The COMMON application's own access and its first administrator (the installing developer).
    procedure seed_common;
    -- release 61: the COMMON administration seed (admin features, COMMON pages, Common Administrator privileges).
    procedure seed_admin;
end xxfnd_share_pkg;
/
