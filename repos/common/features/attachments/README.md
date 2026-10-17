# Attachments

COMMON component, module Documents and Records (feature `ATTACHMENTS`).

## Purpose
Document categories, storage and where attachments appear.

## Usage
Pages 130-137: document entities, categories, attachment pages (who may change what, limits), storage per application and category.

## Benefit
One document store and one set of rules (types, sizes, permissions) for every application.

## Depends on (objects of these components are named in its files)
applications, audit-log, data-security, integrations, lookups

## Used by (COMMON components)
applications, change-approvals, documents, flexfields, integrations, lookups, notifications, roles-privileges

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). Documents are kept in the database until a server is set up (Integrations > Servers, Storage).

## Application objects
### Pages
- 130 Document Entities (`pages/p00130-document-entities.apx`)
- 131 Document Entity (`pages/p00131-document-entity.apx`)
- 132 Document Categories (`pages/p00132-document-categories.apx`)
- 133 Document Category (`pages/p00133-document-category.apx`)
- 134 Attachment Pages (`pages/p00134-attachment-pages.apx`)
- 135 Attachment Page (`pages/p00135-attachment-page.apx`)
- 136 Document Storage (`pages/p00136-document-storage.apx`)
- 137 Application Storage (`pages/p00137-storage-rule.apx`)

### Shared components
- `shared-components/lovs.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_ATTACHED_DOCUMENTS`, `XXFND_ATTACHMENT_BLK_ENTITIES`, `XXFND_ATTACHMENT_BLOCKS`, `XXFND_ATTACHMENT_FUNCTIONS`, `XXFND_DOCUMENTS`, `XXFND_DOCUMENT_CATEGORIES`, `XXFND_DOCUMENT_ENTITIES`, `XXFND_DOCUMENT_FILES`, `XXFND_DOC_CATEGORY_USAGES`, `XXFND_ENTITY_CONTAINERS`, `XXFND_STORAGE_CONFIG`
- views: `XXFND_APP_STORAGE_V`, `XXFND_ATTACHED_DOCUMENTS_V`, `XXFND_DOCUMENT_CATEGORIES_VL`, `XXFND_DOCUMENT_ENTITIES_VL`, `XXFND_DOCUMENT_VERSIONS_V`
- packages: `XXFND_ATTACH_PKG`, `XXFND_ATTACH_STORE_PKG`

## Roles and privileges
Privileges `ATTACHMENTS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications). 2. Its schema gets the grants and creates synonyms for the COMMON objects (as KYC script 03 does). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its entities, categories and attachment pages (`XXFND_ATTACH_PKG.REGISTER_ENTITY`, `REGISTER_CATEGORY`, `REGISTER_ATTACHMENT_PAGE`; KYC: 18h), adds files with `ADD_FILE` / `ADD_TEXT`, moves them with `MOVE_DOCUMENTS`, and opens COMMON page 47 (Documents) for a record.

### Public routines
- `XXFND_ATTACH_PKG`: ADD_FILE, ADD_TEXT, ADD_VERSION, ALLOWED_FILE_TYPES, ASSERT_CHANGE, BLOCK_PERMISSION, CATEGORY_ALLOWED, COPY_ATTACHMENTS, DOWNLOAD, DOWNLOAD_CHECKED, MAX_FILE_SIZE_MB, MOVE_DOCUMENTS, OBJECT_NAME, OBJECT_STORAGE_URL, RECORD_VISIBLE, REGISTER_ATTACHMENT_PAGE, REGISTER_CATEGORY, REGISTER_ENTITY, REMOVE, RESOLVE_STORAGE, SAVE_APP_STORAGE, SAVE_CATEGORY_STORAGE, SAVE_ENTITY_DISPLAY_NAME, STORAGE_APPLICATION, UPDATE_DETAILS, UPLOAD_RULES_TEXT (registration: REGISTER_ATTACHMENT_PAGE, REGISTER_CATEGORY, REGISTER_ENTITY)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_attach_pkg.sql`
- `db/packages/xxfnd_attach_store_pkg.sql`
- `db/tables/xxfnd_attached_documents.sql`
- `db/tables/xxfnd_attachment_blk_entities.sql`
- `db/tables/xxfnd_attachment_blocks.sql`
- `db/tables/xxfnd_attachment_functions.sql`
- `db/tables/xxfnd_doc_category_usages.sql`
- `db/tables/xxfnd_document_categories.sql`
- `db/tables/xxfnd_document_entities.sql`
- `db/tables/xxfnd_document_files.sql`
- `db/tables/xxfnd_documents.sql`
- `db/tables/xxfnd_entity_containers.sql`
- `db/tables/xxfnd_storage_config.sql`
- `db/views/xxfnd_app_storage_v.sql`
- `db/views/xxfnd_attached_documents_v.sql`
- `db/views/xxfnd_document_categories_vl.sql`
- `db/views/xxfnd_document_entities_vl.sql`
- `db/views/xxfnd_document_versions_v.sql`
- `pages/p00130-document-entities.apx`
- `pages/p00131-document-entity.apx`
- `pages/p00132-document-categories.apx`
- `pages/p00133-document-category.apx`
- `pages/p00134-attachment-pages.apx`
- `pages/p00135-attachment-page.apx`
- `pages/p00136-document-storage.apx`
- `pages/p00137-storage-rule.apx`
- `shared-components/lovs.apx`
