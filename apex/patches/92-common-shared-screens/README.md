# Patch 92 - COMMON: shared screens (release 85, COMMON only)

## What changes
- **Attachments (47) and Document (48)** for the record of any application: download, add, replace with a new
  version, remove. The application opens page 47 with its alias, page, region, entity and key (unrestricted
  arguments); the calling page's attachment registration says who may add, replace or remove there
  (XXFND_ATTACH_PKG.ASSERT_CHANGE) and the record must be one the user may see (RECORD_VISIBLE: its table's data
  security). Downloads are checked the same way (DOWNLOAD_CHECKED). COMMON's own Communications page (45) is
  registered: each e-mail has a Documents link (add and replace).
- **Platform Activity (170):** slowest pages, top users, errors and page views of every registered application.
- **Feedback (171, 172 follow-up) and Give Feedback (173):** a Feedback link in the navigation bar; any application
  links to page 173 with its application and page. XXFND_APPLICATION_PKG.SUBMIT_FEEDBACK / FEEDBACK_FOLLOW_UP.
- New features DOCUMENTS, PLATFORM_ACTIVITY, GIVE_FEEDBACK and USAGE_FEEDBACK when missing (privileges given to the
  roles once, when created).

## Files
- `db/`: 09d (feedback), 14 (RECORD_VISIBLE, DOWNLOAD_CHECKED, ASSERT_CHANGE), 27 (new: features, pages, the page
  45 registration), `manifest.json`
- `app/`: `application.apx` (Release 85), pages 45, 47, 48, 170, 171, 172, 173; lists (Feedback link), breadcrumbs
- `ADMIN-GUIDE.md`: Documents, activity and feedback (release 85)

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_85.zip` over COMMON (App Builder import; supporting objects run the upgrade
scripts; data kept). A re-run changes nothing. No data is deleted. **KYC needs its own release** (its attachment
dialogs 90 / 91, activity reports 10030 and feedback pages 10050-10052 move to COMMON's).

## Tests
`apex/tests/r85_shared_test.sql` (as XXFUSION; its rows stay: the communication "R85 document test", a feedback) and
`apex/tests/r85_shared_ui.py`.
