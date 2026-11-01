# Attachments - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Attachments setup

- **Purpose:** document categories, storage and where attachments appear.
- **What it does:** defines document entities, categories, attachment pages (who may change what, size and type limits) and storage per application and category (database or OCI Object Storage).
- **Why:** one document store and one set of rules for every application.

* **How it works:** an application registers which records take documents and where; uploads go to the store set for that application and category.
* **How it's built:** *APEX:* interactive grids, forms, REST calls to Object Storage (`APEX_WEB_SERVICE`). *Custom:* `XXFND_ATTACH_PKG`, 11 tables, 5 views.

- **DB objects:** *Own:* Tables: XXFND\_ATTACHED\_DOCUMENTS, XXFND\_ATTACHMENT\_BLK\_ENTITIES, XXFND\_ATTACHMENT\_BLOCKS, XXFND\_ATTACHMENT\_FUNCTIONS, XXFND\_DOCUMENTS, XXFND\_DOCUMENT\_CATEGORIES, XXFND\_DOCUMENT\_ENTITIES, XXFND\_DOCUMENT\_FILES, XXFND\_DOC\_CATEGORY\_USAGES, XXFND\_ENTITY\_CONTAINERS, XXFND\_STORAGE\_CONFIG; Views: XXFND\_APP\_STORAGE\_V, XXFND\_ATTACHED\_DOCUMENTS\_V, XXFND\_DOCUMENT\_CATEGORIES\_VL, XXFND\_DOCUMENT\_ENTITIES\_VL, XXFND\_DOCUMENT\_VERSIONS\_V; Packages: XXFND\_ATTACH\_PKG. *Uses:* XXFND\_LOOKUP\_PKG, XXFND\_LOOKUP\_VALUES\_VL, XXFND\_SERVERS, XXFND\_SERVERS\_V, XXFND\_SETUP\_COLUMNS\_V, XXFND\_SETUP\_TABLES\_V.

* **Shared components:** App items: G\_ADMIN\_APP, G\_ADMIN\_LOCK; Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; LOVs: lov-applications, lov-categories, lov-doc-datatype, lov-entities; Lists: administration; Page groups: administration.

## Change - Cleanup done (COMMON 108 / KYC 101)

- Removed: authorization `admin-app`, LOV `lov-dff-columns`, table `XXFND_TRANSMISSIONS` (dropped on a database only while it is empty), and the 5 wrapper routines (the install calls `XXFND_SCHEMA_PKG` directly).
- Kept: `XXFND_INTEGRATION_CHANGES_V` is used (read through the configuration tables). `XXFND_DOCUMENT_VERSIONS_V` and `XXFND_QA_HISTORY_V` are kept as application-facing views.
- Page 116 (Notification Delivery) uses the shared LOVs `ENABLED_APPLICATIONS` and `NOTIFICATION_TEMPLATES`.
- COMMON no longer names KYC: the party-details access rule moved to the KYC party package, there is no `KYC` fallback for upload limits, KYC lookups are registered by KYC only, the KYC-dependent tests moved to KYC, and the comments use generic examples.
- Lists, LOVs and authorizations are one file per component.
