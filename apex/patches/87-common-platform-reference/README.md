# Patch 87 - COMMON: Platform and Reference Data packages (release 80, COMMON only - C1 and C3)

## What changes
- **One package per component** (old packages dropped with the checked `XXFND_DDL_PKG.DROP_OBJECT`; their DDL is kept
  in `XXFND_DROPPED_OBJECTS`):
  - `XXFND_APPLICATION_PKG` = `XXFND_APP_FUNCTION_PKG` + `XXFND_SETUP_TYPE_PKG` + `XXFND_ADMIN_SCOPE_PKG`. The scope
    policies and the level triggers are re-created on it. The setup type applications (page 163) are saved by it.
  - `XXFND_APP_SETTING_PKG` (new): optional feature status and setting values (pages 10021, 10023 call it instead of
    APEX API code on the page).
  - `XXFND_LOOKUP_PKG` (new): the lookup helpers, moved from `XXFND_UTIL_PKG`.
  - `XXFND_DFF_PKG` = + the flexfield setup checks, the reporting views and the flexfield name (page 153);
    `XXFND_DFF_SETUP_PKG` dropped. Reporting views over other schemas' tables leave XXFUSION.
- Unused views dropped: `XXFND_ADMIN_APPLICATIONS_V`, `XXFND_DF_SEGMENTS_VL`.
- "All applications (instance)" now reads **"Workspace (all applications)"**.
- Pages 161, 102 and 153: short fields side by side.
- **KYC stops using the old names** and needs its own release (decided: no wrappers).

## Files
- `db/`: 05 and 05 upgrade, 05c (new), 09 (view drop), 09d (renamed `09d-application-pkg.sql`), 10, 11, 12, 15c, 16h,
  16i, 16j, 19, 21b, 21c, 21d (new), `manifest.json`
- `app/`: `application.apx` (Release 80); pages 102, 153, 161, 163, 10021, 10023 (saves through the component
  packages); pages 101, 107, 110, 112, 113, 120-124, 131-133, 135-137, 147, 150, 151, 162 (lookup calls and the
  "Workspace (all applications)" label); shared components `lovs.apx`, `app-processes.apx`, `authorizations.apx`

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_80.zip` over COMMON with **Parsing Schema = XXCUS** and
**Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
A re-run changes nothing.

## Tests
`apex/tests/r80_platform_test.sql` (as XXFUSION) and `apex/tests/r80_platform_ui.py`.
