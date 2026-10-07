# Patch 51 – COMMON audit log, retention, workflow setup, features and settings (release 67, COMMON only)

## What changes
- Copied from KYC into COMMON (same page numbers): Audit Log (111), Retention Policies (112, 113), Deadlines and
  Escalation (145, 146), Process Catalogue (147), Feature Configuration (10020, 10021), Application Settings
  (10022, 10023), with their lists of values and breadcrumbs. This completes the COMMON setup screens.
- Scope: retention policies by the database scope; features, settings and the task-definition lists (delegations,
  deadlines) act on the APEX application of the application in scope (XXFND_ADMIN_SCOPE_PKG.APEX_APP_ID - recorded
  when that application is first signed into). APEX can change only the running application's settings, so another
  application's settings are changed in that application (the screen says so).
- The COMMON administration seed (script 21) is now XXFND_SHARE_PKG.SEED_ADMIN, so the one-time move of an
  application's shared data re-applies it.

## Verified locally
clean → import → fresh install 0 errors / 0 invalid; upgrade 0 errors; scope test 4/4; ADMIN opens all 26 COMMON
pages; a user without an admin role is refused.

## Deploy
Import COMMON-Application-APEXlang_67.zip over COMMON (Parsing Schema XXFUSION), Install Supporting Objects: Yes.
