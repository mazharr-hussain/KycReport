# Patch 72 - E-mail with outside parties from the RFI and Notes screens (R27) (release 74)

## What changes
- COMMON 15e: XXFND_COMMUNICATIONS and XXFND_COMMUNICATION_PKG - send an e-mail for a record (APEX mail,
  optional attachment; recorded as Not Sent while e-mail is switched off) and record a received e-mail.
- Outlook provision: endpoint OUTLOOK_GRAPH (inactive), purpose EMAIL_SYNC, message and conversation IDs kept.
- KYC: drawer 34 E-mail; region E-mails on the case Notes and RFIs (211) and on the RFI (31).

## Files
- `db/15c-rfi-workflow.sql`
- `app/KYC/pages/p00031-request-for-information.apx`
- `app/KYC/pages/p00034-email.apx`

Files shared with other release 74 parts are listed once, in the patch of their latest change.

## Deploy (release 74, in this order)
The release zips carry every patch of release 74 (65-74); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_74.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_74.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   Or, instead of both imports, run `COMMON-Application-SQL-Install_74.sql` then
   `KYC-Compliance-Platform-SQL-Install_74.sql` as ADMIN in SQL Developer Web (see each `install/<app>/INSTALL.md`).
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
