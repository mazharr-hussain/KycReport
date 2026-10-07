# Patch 36 – the COMMON schema is XXFUSION (release 51)

The schema of the COMMON application is **XXFUSION**, not XXFUS. XXFUSION is a schema of the XXCUS workspace, and
XXCUS stays the primary schema.

## What changes
- COMMON application: parsing schema **XXFUSION**; source folder `src/database/xxfusion/apex_apps/f135`.
- ADMIN script renamed `admin/create-xxfusion-schema.sql` (in the COMMON zip). Where XXFUSION already exists in
  the workspace it only applies the grants.
- INSTALL.md, supporting-object messages and comments name XXFUSION.
- KYC (app 134) unchanged.

## Deploy – application import only
1. **App Builder → Import** `COMMON-Application-APEXlang_51.zip` → parsing schema **XXFUSION** → Install
   Supporting Objects: Yes.
   - If COMMON was already imported on XXFUS, import over it. The objects are then installed fresh in XXFUSION.
   - The XXFND_ objects left in XXFUS are no longer used.
2. If the install reports **ORA-20900 ACTION NEEDED**, run the listed grants as ADMIN, then come back:
   Utilities → Supporting Objects → Install Supporting Objects.

## Tested (local)
- XXFUSION created with the ADMIN script.
- Clean install of the 25 COMMON scripts: no invalid objects; COMMON_ADMIN granted to the installer.
- Imported as app 135 with owner XXFUSION; `common_ui.py`: ADMIN gets in; REQ2 is refused.
