# Users Access - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Users and access

- **Purpose:** users, their roles and their data access.
- **What it does:** maintains users (local or SSO, mapped to employees) and the applications each may use; assigns roles and data access rules; runs every application's sign-in and authorization.
- **Why:** one user record and one role assignment for all applications.

* **How it works:** at sign-in COMMON loads the user's roles, applications and data access; each page's authorization asks COMMON. Employees sync daily from Fusion HCM.
* **How it's built:** *APEX:* authentication with post-authentication, authorization schemes, automation (Fusion HCM sync), REST data source, reports. *Custom:* `XXFND_USER_PKG`, 9 tables, 3 views.

- **DB objects:** *Own:* Tables: XXFND\_ASSIGNMENT\_VALUES, XXFND\_DATA\_DIMENSIONS, XXFND\_DATA\_OBJECTS, XXFND\_ROLE\_DATA\_ACCESS, XXFND\_ROLE\_MEMBERS, XXFND\_USERS, XXFND\_USER\_APPLICATIONS, XXFND\_USER\_ROLES, XXHR\_ORGANIZATIONS; Views: XXFND\_USER\_DATA\_ACCESS\_V, XXFND\_USER\_ROLES\_V, XXFND\_USER\_ROLE\_TREE\_V; Packages: XXFND\_USER\_PKG; Triggers: XXFND\_USER\_ROLES\_USER. *Uses:* XXFND\_APPLICATIONS, XXFND\_DATA\_SECURITY\_RULES, XXFND\_EFFECTIVE\_ACCESS\_V, XXFND\_FEATURES, XXFND\_LOOKUP\_VALUES\_VL, XXFND\_PRIVILEGES, XXFND\_PRIVILEGE\_PKG, XXFND\_ROLES, XXFND\_ROLE\_PRIVILEGES, XXFND\_VPD\_PKG, XXHR\_EMPLOYEES.

* **Shared components:** App items: G\_ADMIN\_APP; Authorizations: admin-area, page-create, page-manage, page-submit, page-view; Automations: fusion-hcm-sync; REST data sources: FUSION\_HCM\_WORKERS; Authentication schemes; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.

## Change - Cleanup done (COMMON 108 / KYC 101)

- Removed: authorization `admin-app`, LOV `lov-dff-columns`, table `XXFND_TRANSMISSIONS` (dropped on a database only while it is empty), and the 5 wrapper routines (the install calls `XXFND_SCHEMA_PKG` directly).
- Kept: `XXFND_INTEGRATION_CHANGES_V` is used (read through the configuration tables). `XXFND_DOCUMENT_VERSIONS_V` and `XXFND_QA_HISTORY_V` are kept as application-facing views.
- Page 116 (Notification Delivery) uses the shared LOVs `ENABLED_APPLICATIONS` and `NOTIFICATION_TEMPLATES`.
- COMMON no longer names KYC: the party-details access rule moved to the KYC party package, there is no `KYC` fallback for upload limits, KYC lookups are registered by KYC only, the KYC-dependent tests moved to KYC, and the comments use generic examples.
- Lists, LOVs and authorizations are one file per component.

## Change - Servers and users from APEX (COMMON 109)

- Servers map the workspace's APEX Remote Servers and Web Credentials (listed read-only on Servers); COMMON keeps only the mapping.
- OCI region and namespace are read from the Remote Server URL; the SharePoint / Outlook OAuth token URL comes from an Authentication Remote Server.
- Users: account status (Active / Locked / SSO), failed sign-ins, Lock and Unlock Account.

## Change - Menu group page, RFI lookups (COMMON 111)

- Clicking a menu group opens its group page (page 100): the group's entries the user may open, as cards. The breadcrumb's group level opens the same page. Works for every application's menu.
- `RFI_STATUS`, `RFI_RECIPIENT_TYPE` and `RFI_CATEGORY` are shared COMMON lookups.
- The `KYC_USER` scheme is retired; every application uses `APP_USER` (KYC must switch: COMMON-ISSUES C18).
- Fix: the release 109 install of `XXFND_SERVERS_V` failed in SQL Developer (a comment ending with `;`).
- Retention stays a placeholder.
