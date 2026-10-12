# Patch 80 - Requesting departments by data security; QD users (release 76)

## What changes
- A user raises and sees requests only for the departments their data security allows (rule "column in list" on
  XXCMP_REQUESTS.REQUESTING_DEPARTMENT, e.g. role Requesting Entity - Finance); Create Request lists only those, Save
  refuses any other. Level 1 (all rows) raises requests on behalf of any department.
- COMMON: XXFND_VPD_PKG.ALLOWED_VALUES; index XXFND_USER_ROLES_U1 dropped (it refused a role to a second local user).
- `db/admin/qd-users-and-roles.sql`: Requesting Entity roles (Finance, Procurement), users TEST1-TEST4, Carlos Ferreira,
  Latifa Buzwair, Sandeep Sadasivan, Hissa AlSahlawi (first password Welcome#2026, changed at first sign-in).

## Files
- `db/09b-security-framework-objects.sql`
- `db/04b-applications-and-users.sql`
- `db/admin/qd-users-and-roles.sql`
- `app/KYC/pages/p00201-create-request.apx`
- `tests/r76_departments_test.sql`

Files shared with other release 76 parts are listed once, in the patch of their latest change.

## Deploy (release 76, COMMON + KYC)
The release zips carry every patch of release 76 (78-82); deploy them once, not patch by patch. No SQL install script
from this release on.
1. COMMON: import `COMMON-Application-APEXlang_76.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
   Wait until it has finished.
2. KYC: import `KYC-Compliance-Platform-APEXlang_76.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   KYC stops with ORA-20904 (nothing changed) when COMMON 76 is not installed yet: finish step 1, then run KYC again.
3. QD only, once: run `apex/db/admin/qd-users-and-roles.sql` connected as XXFUSION (users, Requesting Entity roles,
   request approval by Level 1, Contributors without Case Assignment / Create Request). Re-running it changes nothing.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
