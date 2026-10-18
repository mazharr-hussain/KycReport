# Patch 104 - KYC 93: approval rules through COMMON's routines; KYC tests without direct writes to COMMON

Build: `KYC-Compliance-Platform-APEXlang_93.zip` (application version "Release 93"). KYC only; COMMON is not
changed. Install COMMON 90 (patch 103) first.

## What changes
1. **Script 16l (approval rules).**
   - **Before:** COMMON 88 and later refuse direct writes from applications. 16l still inserted the case approval
     rules into COMMON's tables, so the whole block failed (ORA-01031). A new KYC install then had no approval types or
     rules, and submitting a KYC request was refused ("No approval rule applies").
   - **Now:** 16l registers them with COMMON's routines: `REGISTER_TYPE`, `REGISTER_DEFAULT_RULE` (request and RFI),
     and `REGISTER_RULE` per risk tier (two levels for high risk and for enhanced KYC). As before, the case rules are
     added only when KYC_CASE has no rule yet, so rules the administrators changed are kept.
2. **KYC tests.** Six tests wrote COMMON's tables directly and failed on COMMON 88 and later. They now use COMMON's
   routines:
   - `test_users.sql`: `XXFND_USER_PKG.BOOTSTRAP_ADMIN` (employee and role).
   - `security_test.sql`: `XXFND_RFI_PKG.CREATE_RFI` (the two test RFIs, without tasks).
   - `request_party_test.sql`: `REGISTER_RULE` / `UNREGISTER_RULE` (its test rule).
   - `r73_kyc_test.sql`: `XXFND_WORKFLOW_PKG.SET_PROCESS_ENABLED` (the workflow switch).
   - `r76_kyc_test.sql`: `REGISTER_RULE` / `UNREGISTER_RULE` for its rules without steps.
   - Where COMMON has no routine yet, a test-only helper is used instead of direct writes:
     - delegations, in `workflow_test.sql` (COMMON issue C13);
     - switching approval rules and role grants off and on, in `r76_kyc_test.sql` (COMMON issue C14).
   - The helper is `tests/common_test_fixtures.sql`, run as XXFUSION on the test database only. It is not part of
     COMMON or of the KYC install. `run_all.sh` creates it first (saved connection name `xxfusion_local`).

## Files
- `db/16l-kyc-approval-setup.sql`
- `app/application.apx` (Release 93)
- `tests/`:
  - `common_test_fixtures.sql` (new)
  - `test_users.sql`, `security_test.sql`, `workflow_test.sql`, `request_party_test.sql`, `r73_kyc_test.sql`,
    `r76_kyc_test.sql`
  - `run_all.sh`

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_93.zip` over KYC (134), Parsing Schema XXCUS, Install Supporting
Objects: Yes. On a server where KYC was installed on COMMON 88 or later, 16l now creates the missing approval types and
rules; elsewhere it changes nothing.

## Tests (local database, COMMON 90 with KYC 93)
- 16l:
  - With KYC_CASE's rules removed, 16l created the 7 rules: KYC_REQUEST Default, KYC_CASE Low / Medium / High plus Low
    and Medium enhanced, CASE_RFI. There was no error.
  - A second run changed nothing.
- The KYC DB tests of the changed area:

  | Test | Result |
  | --- | --- |
  | `kyc_flow_test` (submit, approve, case) | 23 pass |
  | `workflow_test` | 19 pass |
  | `request_party_test` | 48 pass |
  | `r76_kyc_test` | 14 pass |
  | `r73_kyc_test` | 9 pass, run after `party_test` 21 pass, which provides the PERSON party it needs |
  | `security_test` | expected visibility: REQ1 / REQ2 see only their own RFI; OFFICER1 and ADMIN see both |

- Nothing else in KYC was changed or re-tested.
