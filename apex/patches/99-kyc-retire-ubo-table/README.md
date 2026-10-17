# Patch 99 - KYC beneficial-owner table retired (release 92, KYC only)

- **XXCMP_UBO_DETERMINATIONS retired.** Nothing writes it since page 214 went (release 91); beneficial owners are marks
  on the owner / officer relationship since release 73. The case checklist (16s), the party merge (16e) and the
  one-time copy of release 73 (16b; every supported database, release 74 or later, has it) no longer read it. The table,
  its rows and its foreign key index stay; the table comment says it is retired.
- **18h** no longer registers the lookup UBO_STATUS (its column went in 16f). An existing database keeps the lookup
  (COMMON has no unregister routine: COMMON issue C9).
- **Tests.** workflow_test leaves COMMON's CONFIG_CHANGE approval to COMMON; r74_kyc_test and monitoring_test report
  SKIP when the data other tests create is missing; new kyc92_retire_test.sql.

## Files
- `db/`: 16b-kyc-requests-cases.sql, 16e-party-pkg.sql, 16s-case-pkg.sql, 16v-performance.sql, 18h-register-with-common.sql
- `app/`: application.apx (Release 92)

## Deploy (KYC only)
1. COMMON 86 is installed (application 135) and KYC is at release 91.
2. Import `KYC-Compliance-Platform-APEXlang_92.zip` over KYC (App Builder import); the supporting objects run the
   upgrade scripts. Data is kept; a re-run changes nothing.

## Tests
- Fresh install (COMMON 86 + KYC), re-run, upgrade from release 74 (COMMON, then KYC twice): 0 errors, no invalid
  object.
- All KYC DB tests pass on the fresh and the upgraded database (kyc92_retire_test 4/4, r74_perf 7/7, party 21,
  r74_case 16, workflow 19, r74_kyc, kyc87-91), except r74_risk_test 1 check (COMMON issue C2). monitoring_test skips
  on a new database until the browser tests have approved parties.
- Browser tests not run: no screen changed; they are blocked by COMMON issue C1.
