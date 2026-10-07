# Patch 50 – COMMON integration screens (release 66, COMMON only)

## What changes
Copied from KYC into COMMON (same page numbers): Integration Endpoints (120, 121), Integration Purposes (122, 123),
Transmission Log (124, 125), with their lists of values and breadcrumbs. Endpoints and purposes are scoped by the
application selected on the Administration pages (database scope from release 61); the transmission log shows the
transmissions of the purposes in scope.

## Verified locally
Validation OK; ADMIN opens 120-125; a user without an admin role is refused. Database scripts unchanged.

## Deploy
Import COMMON-Application-APEXlang_66.zip over COMMON (Parsing Schema XXFUSION), Install Supporting Objects: Yes.
