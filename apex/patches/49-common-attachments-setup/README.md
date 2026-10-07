# Patch 49 – COMMON attachments setup (release 65, COMMON only)

## What changes
Copied from KYC into COMMON (same page numbers): Document Entities (130, 131), Document Categories (132, 133),
Attachment Pages (134, 135), Document Storage (136, 137), with their lists of values and breadcrumbs. Entities,
categories, attachment pages and storage rules are scoped by the application selected on the Administration pages
(database scope from release 61); new rows belong to it. The KYC-only Mandatory Documents (138, 139) stay in KYC.

## Verified locally
Validation OK; ADMIN opens 130-137; a user without an admin role is refused. Database scripts unchanged.

## Deploy
Import COMMON-Application-APEXlang_65.zip over COMMON (Parsing Schema XXFUSION), Install Supporting Objects: Yes.
