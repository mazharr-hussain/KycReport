# Patch 105 - COMMON 91: UI fixes (Home KPI, User page, application per row, Lookup Type)

Build: `COMMON-Application-APEXlang_91.zip` (application version "Release 91"). COMMON only, pages only: no database
script changes, KYC is not changed. Install COMMON 90 (patch 103) first.

## What changes
1. **Home (page 1) - UI issue 1.** The small "Open Tasks" badge is replaced by KPI tiles (Universal Theme Metric Card):
   Open tasks, Overdue tasks (red when above 0) and Unread notifications, each opening its list (My Tasks, Notifications).
2. **User (page 104) - UI issue 3.** The page failed to open ("Error during rendering of page item P104_EMPLOYEE_ID",
   PLS-00428). The Employee list of values started with a comment line, so APEX ran it as PL/SQL; the query now starts
   with SELECT (the comment moved inside). No other COMMON item list of values had this pattern.
3. **Privileges (182) and Segregation of Duties (107) - UI issue 4.** New Application column. On Privileges each granted
   role shows its application (e.g. "Compliance Officer (KYC)"); an application's administrators see their application's
   features plus COMMON's shared ones, and only their own roles; IT (all applications) sees everything.
4. **Lookup Type (102) - UI issue 5.** Customization Level is no longer on the screen. It is set by the registration
   routine (XXFND_LOOKUP_PKG.REGISTER_LOOKUP_TYPE); a type created on the screen keeps the default (User). A System type
   shows a read-only note that its values are protected; the protection itself is unchanged.

## Files
- `app/application.apx` (Release 91)
- `app/pages/p00001-home.apx`, `p00102-lookup-type.apx`, `p00104-user.apx`, `p00107-segregation-of-duties.apx`,
  `p00182-privileges.apx`
- `tests/r91_common_ui.py` (new, browser)

## Deploy
App Builder > Import `COMMON-Application-APEXlang_91.zip` over COMMON (135), as for patch 103. Install Supporting Objects
may be Yes or No: no database script changed.

## Tests (local database, COMMON 91 with KYC 93)
`r91_common_ui.py` as ADMIN: 5/5 pass - Home tiles, User page opens with the Employee list, Application column on
Privileges (roles with their application) and Segregation of Duties, no Customization Level on Lookup Type.
Nothing else in COMMON was changed or re-tested.
