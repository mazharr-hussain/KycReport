# COMMON (app 135) - requirements summary

COMMON is the one shared platform every application uses as it is (schema XXFUSION, APEX app 135). This page is the
summary of the complete requirements; each component's detail is in `components/<component>/requirements.md`, next to its
technical document and (to be written) its user guide, training manual, setup manual, video, narration and subtitles.

This file is synced to the README of the GitHub Project "Common Application" on every merge to main.

## Components

| Component | Purpose | Documents |
|---|---|---|
| App Settings | the settings of the running application. | [requirements](components/app-settings/requirements.md) · [technical](components/app-settings/technical.md) |
| Application Menu | the navigation (side menu and top bar) of every application, managed in one place. | [requirements](components/application-menu/requirements.md) · [technical](components/application-menu/technical.md) |
| Applications | one register of every application that uses COMMON. | [requirements](components/applications/requirements.md) · [technical](components/applications/technical.md) |
| Approval Setup | who approves which record, step by step. | [requirements](components/approval-setup/requirements.md) · [technical](components/approval-setup/technical.md) |
| Attachments | document categories, storage and where attachments appear. | [requirements](components/attachments/requirements.md) · [technical](components/attachments/technical.md) |
| Audit Log | who changed what and when. | [requirements](components/audit-log/requirements.md) · [technical](components/audit-log/technical.md) |
| Change Approvals | maker-checker on setup data of every application. | [requirements](components/change-approvals/requirements.md) · [technical](components/change-approvals/technical.md) |
| Communications | e-mails with outside people about a record. | [requirements](components/communications/requirements.md) · [technical](components/communications/technical.md) |
| Data Model | live documentation of every application's database objects. | [requirements](components/data-model/requirements.md) · [technical](components/data-model/technical.md) |
| Data Security | which rows each user and role can see. | [requirements](components/data-security/requirements.md) · [technical](components/data-security/technical.md) |
| Documents | the documents of a record of any application. | [requirements](components/documents/requirements.md) · [technical](components/documents/technical.md) |
| Flexfields | extra fields on a record without a database change. | [requirements](components/flexfields/requirements.md) · [technical](components/flexfields/technical.md) |
| Give Feedback | anyone gives feedback on the page they are on, in any application. | [requirements](components/give-feedback/requirements.md) · [technical](components/give-feedback/technical.md) |
| Home | the landing page of COMMON. | [requirements](components/home/requirements.md) · [technical](components/home/technical.md) |
| Information Requests | ask a colleague or an outside person for information on a record. | [requirements](components/information-requests/requirements.md) · [technical](components/information-requests/technical.md) |
| Integrations | outbound connections and their log. | [requirements](components/integrations/requirements.md) · [technical](components/integrations/technical.md) |
| Lookups | the lists of values used across applications. | [requirements](components/lookups/requirements.md) · [technical](components/lookups/technical.md) |
| My Tasks | one inbox for the signed-in user. | [requirements](components/my-tasks/requirements.md) · [technical](components/my-tasks/technical.md) |
| Notifications | messages to users when something happens. | [requirements](components/notifications/requirements.md) · [technical](components/notifications/technical.md) |
| Optional Features | switch optional parts of an application on or off. | [requirements](components/optional-features/requirements.md) · [technical](components/optional-features/technical.md) |
| Platform Activity | how every application is used and performs. | [requirements](components/platform-activity/requirements.md) · [technical](components/platform-activity/technical.md) |
| Retention | how long records and documents are kept. | [requirements](components/retention/requirements.md) · [technical](components/retention/technical.md) |
| Roles Privileges | roles, the privileges they grant, and segregation of duties. | [requirements](components/roles-privileges/requirements.md) · [technical](components/roles-privileges/technical.md) |
| Usage Feedback | follow up the feedback people gave. | [requirements](components/usage-feedback/requirements.md) · [technical](components/usage-feedback/technical.md) |
| Users Access | users, their roles and their data access. | [requirements](components/users-access/requirements.md) · [technical](components/users-access/technical.md) |
| Workflow Monitor | business administration of running workflows and tasks. | [requirements](components/workflow-monitor/requirements.md) · [technical](components/workflow-monitor/technical.md) |
| Workflow Setup | the workflow engine around APEX workflows and tasks. | [requirements](components/workflow-setup/requirements.md) · [technical](components/workflow-setup/technical.md) |

## Application-wide components - In use

- **Automations:** `fusion-hcm-sync` (daily employee sync from Fusion HCM), `fusion-objects-run` (runs due Fusion objects and the metadata check), `task-deadlines` (task deadlines and escalation). They run on their schedules.
- **App items:**
  - `NOTIFY_COUNT`: the notification badge in the menu.
  - `G_ADMIN_APP` and `G_ADMIN_LOCK`: the application an administrator is working on, used by the setup pages.
  - `G_RETURN_APP` and `G_USER_HOME_URL`: the way back to the user's home application.
- **App processes:** `JOURNEY_ACTIONS` (called from the global page), `USER_HOME` (called from Home), `SET_ADMIN_APP` (sets the working application).
- **App computations:** `notify-count` and `app-title`, run on every page.
- **Navigation:** lists `navigation-menu` and `navigation-bar` (every application's menu), the breadcrumb and the administration list.
- **Security:** authentication schemes (sign-in); authorizations `page-view`, `page-create`, `page-manage`, `page-submit`, `signed-in-user`, `admin-area`.
- **Workflow:** task definitions `CONFIG_CHANGE`, `RFI_RESPONSE`, `RFI_REVIEW`; workflows `CONFIG_CHANGE`, `RFI`.
- **Other:** email template `XXFND_STANDARD`, REST data sources `FUSION_HCM_WORKERS` and `FUSION_ROOT`, static files (icons, Mermaid), all shared LOVs except `lov-dff-columns`, and all 86 pages.

## Application-wide components - Planned (kept for future use)

- **REST data sources:** `OUTLOOK_MESSAGES`, `SHAREPOINT_DRIVES`, `UCM_CONTENT` (integration roadmap).
- **App items** `G_GIVEN_NAME`, `G_MIDDLE_NAME`, `G_FAMILY_NAME`, `G_LOCALE`, `G_ZONEINFO`: filled from the SSO account at sign-in; nothing reads them yet.
- **Retention:** `XXFND_RETENTION_PKG` and the retention pages, a placeholder until retention is built.

## Changes by release

### Cleanup done (COMMON 108 / KYC 101)

- Removed: authorization `admin-app`, LOV `lov-dff-columns`, table `XXFND_TRANSMISSIONS` (dropped on a database only while it is empty), and the 5 wrapper routines (the install calls `XXFND_SCHEMA_PKG` directly).
- Kept: `XXFND_INTEGRATION_CHANGES_V` is used (read through the configuration tables). `XXFND_DOCUMENT_VERSIONS_V` and `XXFND_QA_HISTORY_V` are kept as application-facing views.
- Page 116 (Notification Delivery) uses the shared LOVs `ENABLED_APPLICATIONS` and `NOTIFICATION_TEMPLATES`.
- COMMON no longer names KYC: the party-details access rule moved to the KYC party package, there is no `KYC` fallback for upload limits, KYC lookups are registered by KYC only, the KYC-dependent tests moved to KYC, and the comments use generic examples.
- Lists, LOVs and authorizations are one file per component.

### Servers and users from APEX (COMMON 109)

- Servers map the workspace's APEX Remote Servers and Web Credentials (listed read-only on Servers); COMMON keeps only the mapping.
- OCI region and namespace are read from the Remote Server URL; the SharePoint / Outlook OAuth token URL comes from an Authentication Remote Server.
- Users: account status (Active / Locked / SSO), failed sign-ins, Lock and Unlock Account.

### Endpoints from REST Source Catalogs (COMMON 110)

- An API call = Remote Server (URL) + Web Credential + REST Source Catalog service (endpoint), all kept in APEX Workspace Utilities.
- A purpose picks a Catalog Service; the call uses the service's endpoint path on the purpose's server, with the server's Web Credential (else the catalog's). Without a catalog service the REST Data Source is used.

### Menu group page, RFI lookups (COMMON 111)

- Clicking a menu group opens its group page (page 100): the group's entries the user may open, as cards. The breadcrumb's group level opens the same page. Works for every application's menu.
- `RFI_STATUS`, `RFI_RECIPIENT_TYPE` and `RFI_CATEGORY` are shared COMMON lookups.
- The `KYC_USER` scheme is retired; every application uses `APP_USER` (KYC must switch: COMMON-ISSUES C18).
- Fix: the release 109 install of `XXFND_SERVERS_V` failed in SQL Developer (a comment ending with `;`).
- Retention stays a placeholder.

### Servers linked to APEX Remote Servers, REST Source Catalogs (COMMON 112)

- A server is linked to its APEX Remote Server; its name and URL are always read from it (a change in Workspace Utilities shows at once). The Web Credential is picked from the workspace's credentials. Type, description and enabled are set when the server is added; state, last call, last test and last error are shown as before.
- The APEX Remote Servers list shows the COMMON server linked to each remote server, or Add (opens the Server form filled in).
- A server has many REST Source Catalogs; a purpose picks its endpoint from the services of its server's catalogs.
- The Server form lists the REST Data Sources of every application in the workspace that use its remote server.
- The Fusion Integration Application route is removed (column dropped).
- Fusion Objects is removed; Fusion endpoints come from the REST Source Catalogs.

### Processes and approval groups (COMMON 113)

- The Process Catalogue lists one row per process (for example KYC case approval, KYC request approval); each process opens its Process page with its approval rules and its approval groups.
- An approval group is a named set of approvers of a process: roles (their active users) and users. A rule level can name a group instead of one role or user; anyone in the group can approve.
- Fixes: the Server form (ORA-00937) and the User form (grid columns) open again.

### Docs structure (release 114 docs)

- Requirements, technical documents and placeholders for the training material per component; summary synced to the Project README.

