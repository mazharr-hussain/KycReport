# Patch 100 - COMMON: basic onboarding, application menu, COMMON issues C1-C6 and C8-C11 (releases 87-88, COMMON only)

One build: `COMMON-Application-APEXlang_88.zip` (application version "Release 88"; it includes release 87).

## What changes
**Release 87**
- **Basic onboarding**: an application's own install registers it in COMMON with the bare minimum (registration rows,
  grants, role `<CODE>_ADMIN` for its administrator, menu entries) and gets its synonyms - generic script
  `db/00c-onboard-with-common.sql`, run as the application's schema (`XXFND_ONBOARD_PKG.ONBOARD_SELF`). It changes no
  APEX setting. The install wizard may ask for `ONBOARD_APP_CODE` (default: the alias) and `ONBOARD_ADMIN_USER`. IT
  switches it off with the COMMON application setting **ONBOARD_SELF_ALLOWED = N**. The full setup stays in
  Applications (165 / 166).
- **Application menu** for the common functions: made by onboarding (My Tasks, Notifications, Shared Setup, Give
  Feedback, one entry per common function), maintained in COMMON (Applications > the application > Menu in the
  Application: Show / Hide); the application adds its own entries with `REGISTER_MENU_ENTRY`. Its navigation list:
  `select * from xxfnd_app_menu_v where app_alias = :APP_ALIAS order by display_sequence`.
- **Caller check**: a COMMON routine changes an application's rows only when called by that application or by COMMON
  (ORA-20192); an application's schema sees only its own setup rows and the shared ones.
- **C1** every signed-in user opens the shared pages (40, 43, 45-48, 143, 144, 173) and sees only their own data;
  **C2** a faulted configuration change no longer blocks a new one; **C3** script 17 changes COMMON's own lookups only;
  **C4** delegated links open COMMON page 99; **C11** the grants run once, as the last script (99).

**Release 88**
- **C10** applications get SELECT, REFERENCES and EXECUTE only (the upgrade revokes INSERT, UPDATE and DELETE);
  `XXFND_APPROVAL_RULE_PKG.REGISTER_RULE` (several rules per type); the e-mail and RFI routines act only for the
  caller's own application.
- **C8 / C9** an UNREGISTER_* routine for every REGISTER_* routine (own rows only; ORA-20196 while business data uses a
  row); deleting a disabled application removes the setup it registered.
- **C5** Information Request (143): documents of the RFI; the answer task is due on the RFI's due date; task settings
  for RFI_RESPONSE / RFI_REVIEW.
- **C6** E-mail (46): the record's contacts are offered under To when the application registered a contact source
  (`XXFND_NOTIFY_PKG.REGISTER_CONTACT_SOURCE`).
- C7 (another application's settings) stays open (`apex/COMMON-ISSUES.md`).

## Files
- `db/`: 05b, 05c, 09b, 09d, 10, 11, 14, 15, 15c, 15d, 16j, 17, 19c, 24, 26, `00c-onboard-with-common.sql` (new,
  generic, run by applications), `31-onboarding-and-menu.sql` (new), `32-registration-removal-rfi-contacts.sql` (new),
  `99-share-with-applications-last.sql` (new), `manifest.json`
- `app/`: application.apx (Release 88, setting ONBOARD_SELF_ALLOWED), pages 0, 40, 43, 45, 46, 47, 48, 143, 144, 166,
  173; authorizations (signed-in-user), application process JOURNEY_ACTIONS, task definitions RFI_RESPONSE / RFI_REVIEW

## Deploy (COMMON only)
1. App Builder > Import `COMMON-Application-APEXlang_88.zip` over COMMON (application 135): **Parsing Schema = XXCUS**,
   **Install Supporting Objects: No**.
2. App Builder > COMMON > Edit Application Definition > Security > Database Session > **Parsing Schema = XXFUSION** >
   Apply Changes.
3. Utilities > Supporting Objects > **Install Supporting Objects** (runs the upgrade scripts; data kept; a re-run
   changes nothing).
4. Check: Applications > an application > **Menu in the Application** lists its entries; a business user opens My
   Tasks in COMMON.

**Impact on KYC (KYC changes later, by the user):** KYC script 16l writes COMMON's approval tables directly; after this
upgrade that fails (no INSERT / UPDATE / DELETE) and must call `REGISTER_RULE`. KYC's pages work as before.

## Tests (COMMON on its own)
- New: `r87_common_test.sql` (as XXFUSION, 29 checks), `r87_app_test.sql` (as XXCUS: the application's side, 15),
  `r87_delete_test.sql` (as XXFUSION, 4). Setup as for release 86: `r86_test_apps.sql` (XXCUS, once),
  `common_test_fixture.sql` (XXFUSION).
- Changed: `r86_registration_test.sql` (a disabled application is now blocked by its business data only, C9).
  Copies of the tests are in `tests/`.
- Install cycle: fresh install 0 errors, install re-run 0 errors; upgrade from release 86 (with an onboarded
  application holding the old write grants) 0 errors, upgrade re-run 0 errors; COMMON DB tests r78-r88, admin_scope and
  r87_* pass on the fresh and the upgraded database (0 failures). `r73_common_test.sql` needs KYC installed (its KYC
  part reports ORA-02291 on a COMMON-only database, as before).
- Browser: a plain signed-in user (TEST1, no COMMON role) opens My Tasks and Notifications (C1).
- App Builder: APEXlang validation successful; the zip imports (`apex import`) and installs its supporting objects.
