# Patch 60 - instance and application setup levels, Table / Key Column lists (release 73, issues 4 and 9)

## What changes
- New Setup Types (COMMON > Administration > Applications > Setup Types): each setup type is Instance only,
  Application only or Both, and can be limited to chosen applications.
- Every setup form has one Application field (single choice): empty = "All applications (instance)"; COMMON is the
  instance, not an application. A form offers only what its setup type allows (also checked in the database).
- Document Entity, Descriptive Flexfield and Retention Policy: Table and Key Column are lists, not typed.

## Files
- `db/21c-setup-types.sql`
- `db/19c-share-with-applications.sql`
- `db/manifest.json`
- `app/COMMON/lovs.apx`
- `app/COMMON/breadcrumbs.apx`
- `app/COMMON/p00162-setup-types.apx`
- `app/COMMON/p00163-setup-type.apx`
- `app/COMMON/p00102-lookup-type.apx`
- `app/COMMON/p00106-role.apx`
- `app/COMMON/p00110-notification-template.apx`
- `app/COMMON/p00113-retention-policy.apx`
- `app/COMMON/p00121-integration-endpoint.apx`
- `app/COMMON/p00123-integration-purpose.apx`
- `app/COMMON/p00131-document-entity.apx`
- `app/COMMON/p00133-document-category.apx`
- `app/COMMON/p00135-attachment-page.apx`
- `app/COMMON/p00137-storage-rule.apx`
- `app/COMMON/p00151-value-set.apx`
- `app/COMMON/p00153-descriptive-flexfield.apx`

Files shared with other release 73 issues are listed once, in the patch where they changed most.

## Deploy (release 73, in this order)
The release zips carry every patch of release 73 (58-64); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_73.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_73.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
