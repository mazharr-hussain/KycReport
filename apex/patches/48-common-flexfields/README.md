# Patch 48 – COMMON value sets and descriptive flexfields (release 64, COMMON only)

## What changes
Copied from KYC into COMMON (same page numbers): Value Sets (150, 151) and Descriptive Flexfields (152, 153), with their
lists of values and breadcrumbs. Value sets and flexfields are scoped by the application selected on the
Administration pages (database scope from release 61); new rows belong to it.

## Verified locally
Validation OK; ADMIN opens 150-153; a user without an admin role is refused. Database scripts unchanged.

## Deploy
Import COMMON-Application-APEXlang_64.zip over COMMON (Parsing Schema XXFUSION), Install Supporting Objects: Yes.
