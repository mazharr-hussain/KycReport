# Patch 113 - COMMON 98: User page layout (UI issues 14, 15, 16)

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

## Files
- `app/application.apx` (Release 98), `app/pages/p00104-user.apx`

## Deploy
App Builder > Import `COMMON-Application-APEXlang_98.zip` over COMMON (135). Install Supporting Objects may be Yes or No.

## Tests
APEXlang validation passed. No browser test (layout only, as agreed).
