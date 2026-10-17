# Applications

COMMON component, module Platform (feature `APPLICATIONS`).

## Purpose
Registered applications, the common functions switched on for each, their setup.

## Usage
IT registers (onboards) every application here (pages 160, 166), defines setup types and levels (162, 163), chooses which common functions an application manages itself (164) and follows the application journey (165).

## Benefit
One register of every application: COMMON knows each application, its APEX ID and schema, and grants and scopes everything (security, setup, workflow) by it.

## Depends on (objects of these components are named in its files)
approval-setup, attachments, data-security, flexfields, integrations, lookups, notifications, retention, roles-privileges, users-access, workflow-setup

## Used by (COMMON components)
app-settings, approval-setup, attachments, change-approvals, data-security, flexfields, give-feedback, information-requests, integrations, lookups, notifications, optional-features, platform-activity, retention, roles-privileges, usage-feedback, users-access, workflow-monitor, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). Script `db/admin/onboard-application.sql` (as XXFUSION) registers a new application; its schema then gets the grants.

## Application objects
### Pages
- 160 Applications (`pages/p00160-applications.apx`)
- 162 Setup Types (`pages/p00162-setup-types.apx`)
- 163 Setup Type (`pages/p00163-setup-type.apx`)
- 164 Subscriptions (`pages/p00164-subscriptions.apx`)
- 165 Application Journey (`pages/p00165-application-journey.apx`)
- 166 Application (`pages/p00166-application.apx`)

### Shared components
- `shared-components/lists.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_APPLICATIONS`, `XXFND_APPLICATION_FUNCTIONS`, `XXFND_SETUP_TYPES`
- views: `XXFND_ADMIN_APPLICATIONS_V`, `XXFND_ADMIN_MENU_V`, `XXFND_MODULES_V`, `XXFND_SETUP_COLUMNS_V`, `XXFND_SETUP_ROWS_V`, `XXFND_SETUP_TABLES_V`
- packages: `XXFND_APPLICATION_PKG`, `XXFND_SETUP_TYPE_PKG`
- sequences: `XXFND_APPLICATIONS_S`
- triggers: `XXFND_APPLICATIONS_ID`
- seed: `XXFND_APPLICATIONS`

## Roles and privileges
Privileges `APPLICATIONS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Before anything else an application is onboarded: `XXFND_APPLICATION_PKG.ONBOARD` (or `apex/db/admin/onboard-application.sql`) with its APEX application ID and code. That grants the application schema the COMMON objects (`XXFND_SHARE_PKG.GRANT_TO`); the application then creates synonyms for them (KYC: script 03). Its own pages call PAGE_ALLOWED / IS_DELEGATED to respect what IT lets it manage. Release 87: the application's own install can register it with the generic script `00c-onboard-with-common.sql` (XXFND_ONBOARD_PKG.ONBOARD_SELF; IT switch: COMMON setting ONBOARD_SELF_ALLOWED), and its navigation list for the common functions is `select * from xxfnd_app_menu_v where app_alias = :APP_ALIAS` (entries maintained here; the application adds its own with REGISTER_MENU_ENTRY). Release 88: every REGISTER_* routine has an UNREGISTER_* routine, and deleting a disabled application removes the setup it registered.

### Public routines
- `XXFND_APPLICATION_PKG`: ADMINISTERS_ANY, APEX_APP_ID, APP_ALLOWED, ASSERT_SAME_APPLICATION, CAN_ADMINISTER, CHECK_LEVEL, COMMON_FUNCTIONS, CREATE_TRIGGERS, DEFAULT_APPLICATION, DELEGATED_ANY, DELEGATED_APP, DELEGATED_URL, DELETE_APPLICATION, DELETE_BLOCKER, ENSURE_MENU, ENSURE_ROWS, FEEDBACK_FOLLOW_UP, IS_COMMON_ADMIN, IS_DELEGATED, IS_MANAGED, LOCAL_PAGE, MENU_URL, MENU_VISIBLE, ONBOARD, PAGE_ALLOWED, PAGE_TYPE, POLICY_CHANGE, POLICY_READ, REGISTERED_CODE, REGISTER_APPLICATION, REGISTER_MENU_ENTRY, REMOVE_ALL_REGISTERED, REMOVE_REGISTERED, SAVE_APPLICATION, SAVE_FUNCTIONS, SAVE_MENU_ENTRY, SAVE_SETUP_TYPE_APPS, SCOPED_TABLES, SETUP_CODE, SETUP_PAGE_URL, SET_APEX_ID, SET_ENABLED, SUBMIT_FEEDBACK, UNREGISTER_MENU_ENTRY (registration: REGISTER_APPLICATION, REGISTER_MENU_ENTRY)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_application_pkg.sql`
- `db/packages/xxfnd_setup_type_pkg.sql`
- `db/seed/xxfnd_applications.sql`
- `db/sequences/xxfnd_applications_s.sql`
- `db/tables/xxfnd_application_functions.sql`
- `db/tables/xxfnd_applications.sql`
- `db/tables/xxfnd_setup_types.sql`
- `db/triggers/xxfnd_applications_id.sql`
- `db/views/xxfnd_admin_applications_v.sql`
- `db/views/xxfnd_admin_menu_v.sql`
- `db/views/xxfnd_modules_v.sql`
- `db/views/xxfnd_setup_columns_v.sql`
- `db/views/xxfnd_setup_rows_v.sql`
- `db/views/xxfnd_setup_tables_v.sql`
- `pages/p00160-applications.apx`
- `pages/p00162-setup-types.apx`
- `pages/p00163-setup-type.apx`
- `pages/p00164-subscriptions.apx`
- `pages/p00165-application-journey.apx`
- `pages/p00166-application.apx`
- `shared-components/lists.apx`
