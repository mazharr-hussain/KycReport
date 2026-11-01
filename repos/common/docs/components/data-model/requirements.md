# Data Model - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Data model

- **Purpose:** live documentation of every application's database objects.
- **What it does:** lists an application's tables, views, packages, types, sequences and triggers; shows one object in full, including what it uses and what uses it; draws the entity-relationship diagram.
- **Why:** an always-current data model, without exports or diagram tools.

* **How it works:** reads the database dictionary live for each application's object prefix and draws the diagram from foreign keys.
* **How it's built:** *APEX:* classic and interactive reports, Mermaid static file for the diagram. *Custom:* `XXFND_DATA_MODEL_PKG`, 2 tables, dictionary views.

- **DB objects:** *Own:* Tables: XXFND\_DM\_APP\_SCOPES, XXFND\_DM\_TABLE\_GROUPS; Packages: XXFND\_DATA\_MODEL\_PKG. *Uses:* the database dictionary.

* **Shared components:** Authorizations: page-manage, page-view; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration; Static files: mermaid.

## Change - Cleanup done (COMMON 108 / KYC 101)

- Removed: authorization `admin-app`, LOV `lov-dff-columns`, table `XXFND_TRANSMISSIONS` (dropped on a database only while it is empty), and the 5 wrapper routines (the install calls `XXFND_SCHEMA_PKG` directly).
- Kept: `XXFND_INTEGRATION_CHANGES_V` is used (read through the configuration tables). `XXFND_DOCUMENT_VERSIONS_V` and `XXFND_QA_HISTORY_V` are kept as application-facing views.
- Page 116 (Notification Delivery) uses the shared LOVs `ENABLED_APPLICATIONS` and `NOTIFICATION_TEMPLATES`.
- COMMON no longer names KYC: the party-details access rule moved to the KYC party package, there is no `KYC` fallback for upload limits, KYC lookups are registered by KYC only, the KYC-dependent tests moved to KYC, and the comments use generic examples.
- Lists, LOVs and authorizations are one file per component.
