# Notifications - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Notifications

- **Purpose:** messages to users when something happens.
- **What it does:** templates, delivery rules (e-mail, in-app, push) and a delivery log.
- **Why:** notifications are data, sent the same way for every application.

* **How it works:** an event names a template; delivery rules choose e-mail, in-app or push; every send is logged.
* **How it's built:** *APEX:* `APEX_MAIL`, push notifications (`APEX_PWA`), email template, interactive grids. *Custom:* `XXFND_NOTIFY_PKG`, 6 tables.

- **DB objects:** *Own:* Tables: XXFND\_NOTIFICATIONS, XXFND\_NOTIFICATION\_TEMPLATES, XXFND\_NOTIFY\_CHANNELS, XXFND\_NOTIFY\_EVENTS, XXFND\_NOTIFY\_RECIPIENT\_TYPES, XXFND\_NOTIFY\_RULES; Packages: XXFND\_NOTIFY\_PKG. *Uses:* XXFND\_APPLICATIONS.

* **Shared components:** App items: G\_ADMIN\_APP, G\_ADMIN\_LOCK; Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; Email templates: XXFND\_STANDARD; LOVs: lov-applications; Lists: administration; Page groups: administration.

## Change - Cleanup done (COMMON 108 / KYC 101)

- Removed: authorization `admin-app`, LOV `lov-dff-columns`, table `XXFND_TRANSMISSIONS` (dropped on a database only while it is empty), and the 5 wrapper routines (the install calls `XXFND_SCHEMA_PKG` directly).
- Kept: `XXFND_INTEGRATION_CHANGES_V` is used (read through the configuration tables). `XXFND_DOCUMENT_VERSIONS_V` and `XXFND_QA_HISTORY_V` are kept as application-facing views.
- Page 116 (Notification Delivery) uses the shared LOVs `ENABLED_APPLICATIONS` and `NOTIFICATION_TEMPLATES`.
- COMMON no longer names KYC: the party-details access rule moved to the KYC party package, there is no `KYC` fallback for upload limits, KYC lookups are registered by KYC only, the KYC-dependent tests moved to KYC, and the comments use generic examples.
- Lists, LOVs and authorizations are one file per component.
