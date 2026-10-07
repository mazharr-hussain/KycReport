# Patch 47 – COMMON lookups and notification templates (release 63, COMMON only)

## What changes
Copied from KYC into COMMON (same page numbers): Lookups (101, 102) and Notification Templates (109, 110), with their
lists of values and breadcrumbs. Lookup types and notification templates are scoped by the application selected on
the Administration pages (database scope from release 61): that application's rows plus the shared rows; new rows
belong to it.

## Verified locally
Validation OK; ADMIN opens 101, 102, 109, 110; a user without an admin role is refused. Database scripts unchanged.

## Deploy
Import COMMON-Application-APEXlang_63.zip over COMMON (Parsing Schema XXFUSION), Install Supporting Objects: Yes.
