# Patch 74 - Performance best practice (R23) (release 74)

## What changes
- The data security policy keeps a user's predicate for a few seconds (a report calling a function per row no
  longer re-reads the rules per row).
- Indexes on the foreign keys of the transaction tables and on the requests' data security column (KYC 16v);
  XXFND_COMMUNICATIONS.IN_REPLY_TO_ID (COMMON 15e). History tables are left as they are.

## Files
- `db/09b-security-framework-objects.sql`
- `db/15e-communications.sql`
- `db/16v-performance.sql`

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
