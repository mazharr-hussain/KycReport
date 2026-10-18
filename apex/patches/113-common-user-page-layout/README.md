# Patch 113 - COMMON 98: User page layout (UI issues 14, 15, 16) and QD users and roles

Build: `COMMON-Application-APEXlang_98.zip` (application version "Release 98"). COMMON only, page 104 only: layout with
standard APEX components; no database or package change; KYC is not changed. Install COMMON 97 (patch 112) first.

## What changes (User, page 104)
- **14 - layout:** multi-column form (12-column grid, 3 fields per row, inputs stretched):
  Kind of User | User Name / Employee | Employee; Full Name | E-mail | Password; Language | Active Until | Status; Notes
  across the full width. The region title is the user's name ("New User" when creating). One button bar at the top of the
  form: Back to Users on the left; Reset Password, Disable / Enable, Create / Save on the right.
- **15 - Applications** (the user's applications, End) shows only in COMMON's scope (COMMON administrator), not when the
  page is used in an application administrator's scope.
- **16 - tabs Roles | Privileges | Data access:** the Privileges tab is an interactive report of every privilege the user
  holds, with the Role that gives it, the role inside it (when it comes from there) and the Application - filter or search
  on any column.

- **QD users and roles** (`db/admin/qd-users-and-roles.sql`, rewritten for the security model of COMMON 96, COMMON
  routines only): roles Requesting Entity1 (Finance) and Requesting Entity2 (Procurement) - each holds Requester and
  reaches KYC Requests by the Department on the assignment; users TEST1 / TEST3 = Entity1 (Finance), TEST2 / TEST4 =
  Entity2 (Procurement); Carlos Ferreira (Contributor, Level 1, Level 2), Latifa Buzwair (Contributor, Level 1), Sandeep
  Sadasivan and Hissa AlSahlawi (Contributor). An existing user is recreated: its roles end (rows kept for the audit; no
  COMMON routine deletes a user), its password is the first one again (Welcome#2026, changed at first sign-in).

## Files
- `app/application.apx` (Release 98), `app/pages/p00104-user.apx`
- `db/admin/qd-users-and-roles.sql`

## Deploy
App Builder > Import `COMMON-Application-APEXlang_98.zip` over COMMON (135). Install Supporting Objects may be Yes or No.
Then run `db/admin/qd-users-and-roles.sql` as XXFUSION (once per environment).

## Tests
APEXlang validation passed. No browser or database test (as agreed).
