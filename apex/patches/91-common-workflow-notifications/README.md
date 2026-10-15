# Patch 91 - COMMON: workflow processes and notifications (release 84, COMMON only)

## What changes
- **RFI and configuration change approval are APEX workflow processes of COMMON** (Shared Components > Workflows: RFI,
  CONFIG_CHANGE; task definitions RFI_RESPONSE, RFI_REVIEW, CONFIG_CHANGE). The RFI asks the person (one task per
  provider), waits for an outside person's answer through the one-time link (public page Provide Information, 50,
  continues the workflow), has the answer reviewed and loops when asked again. A configuration change of a setup
  table with approval (XXFND_CONFIG_TABLES.APPROVAL_FLAG = Y) starts CONFIG_CHANGE; the maker is not an approver.
  XXFND_RFI_PKG and XXFND_APPROVAL_PKG keep the data and the rules and no longer create tasks.
- **Notifications driven by data** (Workflow > Notification Delivery, 116; log 117): channels (in the application -
  the bell and Notifications, 43; e-mail; push; Fusion prepared and off), events, rules (who, which channel) and the
  queries that find the people; wording per event and language (Notification Templates, with the link label). Nothing
  is hardcoded in the packages.
- **COMMON is a progressive web app with push notifications** (each person turns it on per device on page 43).
- **E-mail of a record**: Communications (45, opened by any application for its record) and E-mail (46: send, record
  a received one). New COMMON settings MAIL_FROM and MAIL_FOOTER.
- Task pages Information Request (143) and Configuration Change (144); automation "Task deadlines" (reminders and
  escalations of every application).
- Data security: the task pages show the record only to the task's people or a workflow administrator; system reads
  of the setup (a workflow running in the background) use trusted mode, which the administration scope honours too.

## Files
- `db/`: 05 (approval package spec, install and upgrade copies), 09b (XXFND_VPD_PKG.IS_TRUSTED), 09d (scope honours
  trusted mode), 15 (notification tables, XXFND_NOTIFY_PKG engine, XXFND_WORKFLOW_PKG task events, approval body),
  15c (RFI in the workflow), 24 (the release 82 wording switch runs once only, before the notification events), 26 (new: seeds, privileges, push key pair), `manifest.json`
- `app/`: `application.apx` (Release 84, PWA with push, settings MAIL_FROM / MAIL_FOOTER), workflows, task
  definitions, push credential, automation, app item and computation (bell count), lists, breadcrumbs, pages 43, 45,
  46, 50, 116, 117, 143, 144
- `ADMIN-GUIDE.md`: Notifications (release 84)

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_84.zip` over COMMON (App Builder import: supporting objects run the upgrade
scripts; data kept). Then set MAIL_FROM and MAIL_FOOTER on Application Settings. A re-run changes nothing. No data is
deleted. **KYC needs its own release** (its RFI and configuration change task definitions and pages move to COMMON's).

## Tests
`apex/tests/r84_notifications_test.sql` (as XXFUSION; it commits and waits for the background workflow engine; its
rows stay, entity R84_TEST) and `apex/tests/r84_notifications_ui.py`.
