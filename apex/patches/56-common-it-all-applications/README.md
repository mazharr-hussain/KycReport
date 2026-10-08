# Patch 56 – COMMON for IT, every application on the setup screens, Administration tree, applications and their common functions (release 71: COMMON only)

## What changes
- **COMMON is for IT only.** Only users with the role Common Administrator (COMMON_ADMIN) can sign in and use it;
  anyone else (an application administrator too) is refused and sees no setup rows.
- **Two ways to look at the setup.** The Application selector at the top of every Administration page opens on
  **All applications**: every component screen lists all applications' rows with an **Application** column (filter it
  with the report's Actions > Filter). Choose one application to see only its rows and the shared rows; the choice
  stays while you move between screens.
- **Forms:** an **Application** field on every setup form (empty = shared by every application; a role always belongs
  to one application). With one application chosen it is filled in.
- **Feature Configuration / Application Settings** belong to one application: on All they ask you to choose one.
- **Navigation menu:** Home and an **Administration** tree - Basic Setup, Workflow & Integration, Security,
  Application - with every component opening directly.

- **Applications** (Administration > Application > Applications, pages 160/161): IT registers an application (code,
  name, APEX application, schema), which gives its schema the grants on the shared objects. Each application has a
  switch per **common function** (Lookups, Flexfields, Attachments, Notifications, Retention, Workflow Setup,
  Integrations, Users & Access, Roles & Privileges, Data Security, Audit Log, Application Settings): a new application
  starts with all off; KYC and COMMON start with all on (nothing changes for them). The **Setup Overview** shows, per
  function, whether it is on, how many setup rows the application has, and opens the screen filtered to it.
- Setup forms offer an application only when the page's function is switched on for it.

## Database (COMMON: 16i, 16j, 19c, new 21b - re-run on upgrade)
- 21b: XXFND_APPLICATION_FUNCTIONS and XXFND_APP_FUNCTION_PKG (IS_ENABLED - what an application asks before it
  shows or runs a common function; used by KYC from the next release).
- 16i: the scope policies become a view filter for IT (no rows for anyone else); default ALL.
- 16j: COMMON sign-in and Administration = Common Administrator.

## Deploy
COMMON: import `COMMON-Application-APEXlang_71.zip` over COMMON (import as XXCUS, Parsing Schema XXFUSION - see
`apex/install/COMMON/INSTALL.md`), Install Supporting Objects: Yes (upgrade). Then make sure every IT administrator
has the role Common Administrator (Administration > Users & Access) before others lose access.
