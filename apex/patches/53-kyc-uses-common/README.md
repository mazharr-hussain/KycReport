# Patch 53 – KYC uses the COMMON setup screens (release 68: COMMON and KYC)

## What changes
- **KYC:** its copies of the shared setup screens are removed (lookups, users and access, roles, segregation of
  duties, notification templates, audit log, retention, delegations, integration, attachments setup, workflow
  deadlines and catalogue, value sets, descriptive flexfields, data security, privileges: pages 101-115, 120-125,
  130-137, 145-147, 150-153, 180-182) with their breadcrumbs and the lists of values only they used.
  KYC's Administration menu and feature tabs open those screens in COMMON for KYC. KYC's own setup screens stay in
  KYC: KYC rules, mandatory documents, approval matrix and request approval paths, alert rules, workflow monitor,
  application settings and optional features, usage and feedback.
- **Both applications:** workspace session sharing on every authentication scheme: going from KYC to COMMON keeps
  the session (no second sign-in).
- **COMMON:** page 99 (Open Setup): the entry point another application links to (application, page); it locks the
  screens to that application (no selector). Feature tabs on the COMMON setup pages. The data security rule form
  lists the tables and columns of the application in scope (its schema).
- **Database (COMMON, 16i):** `XXFND_ADMIN_SCOPE_PKG.SETUP_PAGE_URL(page)` - the page in the running application
  when it has it, otherwise in COMMON for that application (used by KYC's admin menu and tabs).

## Verified locally (from a restored pre-move backup, the full sequence)
clean-common → COMMON import + fresh install 0 errors / 0 invalid → move script (0 invalid in both schemas) → KYC
upgrade 0 errors → import both. KYC → Administration → Lookups opens in COMMON (no second sign-in, locked to KYC,
KYC's rows); mixed feature tabs route to KYC or COMMON; all 24 COMMON pages open; admin test (rules, privileges,
settings) passes; KYC database tests pass except the known older-test items (security_test test-data, kyc_flow_test
report-conclusion check) and two checks that count tasks of earlier test runs.

## Deploy (in this order)
1. COMMON: import `COMMON-Application-APEXlang_68.zip` over COMMON (Parsing Schema XXFUSION), Install Supporting
   Objects: Yes. (Clean start: patch 44 steps.)
2. Once, if not done yet: as ADMIN run `apex/db/admin/move-kyc-shared-data-to-xxfusion.sql` (Run Script F5).
3. KYC: import `KYC-Compliance-Platform-APEXlang_68.zip` over app 134, Install Supporting Objects: Yes.
