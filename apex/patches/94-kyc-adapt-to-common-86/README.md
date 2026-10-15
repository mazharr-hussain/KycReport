# Patch 94 - KYC adapted to COMMON 86 (release 87, KYC only)

KYC runs on the completed COMMON again. COMMON is not changed.

## What changes
- **COMMON's current packages.** KYC called 8 COMMON objects that COMMON had removed or renamed. Every call now goes
  to the current package, with the same members (225 calls):
  - XXFND_TASK_PKG and XXFND_WORKFLOW_SWITCH_PKG -> XXFND_WORKFLOW_PKG
  - XXFND_AUTH_PKG -> XXFND_USER_PKG
  - XXFND_SECURITY_PKG -> XXFND_USER_PKG (BOOTSTRAP_ADMIN, RENAMING) / XXFND_PRIVILEGE_PKG (SOD_CONFLICT)
  - XXFND_ADMIN_SCOPE_PKG -> XXFND_APPLICATION_PKG
  - XXFND_COMMUNICATION_PKG -> XXFND_NOTIFY_PKG (page 34)
  - XXFND_CONFIG_APPROVAL_PKG -> XXFND_APPROVAL_PKG
  - XXFND_UTIL_PKG.LOOKUP_MEANING -> XXFND_LOOKUP_PKG.LOOKUP_MEANING
- **KYC registers itself in COMMON** (new script `18h-register-with-common.sql`) through COMMON's registration
  routines. It registers its roles and SoD rules, features, privileges and pages, its lookups (moved here from
  17, 18e and 18f), value sets and flexfields, document entities, categories and attachment pages, integration
  purposes, the KYC_ALERT template, task deadlines, data access rules, configuration tables, its workflows as
  processes and the first administrator. Scripts 18, 18b, 18c, 18d, 18e and 18f no longer write COMMON tables.
  - First-install grants are given only on a new database, so a privilege removed in COMMON's console stays removed.
  - KYC uses COMMON's own `OTHER` category and its `XXFND_COMMUNICATIONS` entity.
- **Approval defaults.** The request default rule and the case-RFI default rule are registered with
  REGISTER_DEFAULT_RULE (16l). The case rules (one per risk tier, two levels for high risk and enhanced KYC) are still
  copied from the approval matrix, only on a database whose KYC_CASE type has no rule yet. This is because COMMON
  registers one default rule per type. It is the only place KYC still writes COMMON rows.
- **Party merge.** Documents move with `XXFND_ATTACH_PKG.MOVE_DOCUMENTS` (16e).
- **Install checks (03).**
  - The install requires COMMON 86.
  - It also requires KYC to be registered in COMMON. Otherwise it stops with ORA-20905, changing nothing.
  - It drops the synonyms of COMMON objects that no longer exist.
- **Automations.** KYC's `task-deadlines` and `fusion-hcm-sync` automations are removed: COMMON runs both for every
  application. The KYC monitoring automation stays.
- **Removed seeds.** The retired endpoint and the UCM storage rule are no longer seeded. Documents stay in the
  database until COMMON's administrator sets up a server.
- **Retired scripts.** 17 now runs for COMMON only. 16k (the one-time RFI copy of release 74) is retired.
- **Page mapping.** Pages 138, 139 (mandatory documents) and 165 (SAR gate) belong to KYC Rules.

## Files
- `db/`:
  - Changed: 03, 16b, 16c, 16e, 16g, 16i, 16l, 16r, 16s, 16u, 18, 18b, 18c, 18d, 18e, 18f, 19b, manifest.json
  - New: 18h-register-with-common.sql
  - Removed: 16k
- `app/`:
  - application.apx (Release 87)
  - Pages 0, 1, 20, 21, 30, 31, 34, 98, 138, 160, 161, 163, 200, 203, 206, 210, 211, 217, 220, 221, 222, 225, 230
  - Lists, authentications, authorizations, 7 task definitions, 2 workflows
  - 2 automations removed

## Deploy (KYC only)
1. COMMON 86 is installed and its install has finished.
2. Import `KYC-Compliance-Platform-APEXlang_87.zip` over KYC (App Builder import; the supporting objects run the
   upgrade scripts; data is kept).
3. New database only: register KYC in COMMON first, as XXFUSION: `apex/db/admin/onboard-application.sql` with the KYC
   APEX application ID and code KYC. Then **Utilities → Supporting Objects → Install Supporting Objects**.
   An existing KYC is already registered.

A re-run changes nothing. The database must already be at KYC release 74 or later.

Notes:
- **Retention policies.** A database that comes straight from KYC 74-76 keeps the 6 retention policies KYC once
  seeded. Release 77 removed them, but they are COMMON rows now. COMMON's administrator can remove them on the
  Retention screen.
- **Page mapping on existing databases.** On an existing database, pages 138, 139 and 165 keep their current feature,
  because registration never overrides an administrator's mapping.

## Tests
- **Install cycle.** All runs gave 0 errors and no invalid object:
  - COMMON 86 fresh install, KYC registered with `onboard-application.sql`, KYC fresh install.
  - KYC re-run over the existing objects.
  - Upgrade from release 74 (COMMON, then KYC twice).
  - APEXlang validation of KYC passes.
- **New test `apex/tests/kyc87_adapt_test.sql`: 23 of 23 pass**, on the fresh and the upgraded database. It checks:
  - registration and ownership in COMMON
  - no stale synonym and no invalid object
  - the automations
  - the party merge moving documents through COMMON
- **KYC database tests.** These pass: kyc_flow 23, party 21, request_party 48, r73_kyc 9, r74_party 15, r74_case 16,
  r74_email 6, r74_perf 7, r75_kyc 9, r76_kyc 14. monitoring passes 20 of 20 on the upgraded database; on a new one
  it needs approved parties from the browser tests first.
- **KYC browser tests pass:** kyc_ui 32, party_ui 23, request_party_ui 24, r74_party_ui 10, r74_case_ui 10,
  r74_email_ui 5, r75_ui 13.
- **Known failures, not caused by this release.** These tests still expect KYC's own RFI and change-approval tasks.
  Since COMMON 84 those are COMMON workflows, so the tasks belong to the COMMON application and appear only once the
  workflow has run.
  - workflow_test (RFI part, 4 checks)
  - r74_kyc_test (RFI raised from the case, 2 checks)
  - r74_risk_test (1 check, on a database where an earlier run left the change workflow faulted)
  - r74_risk_ui (last step)

  They are rewritten with KYC's RFI and change-approval screens in releases 88 and 89.
