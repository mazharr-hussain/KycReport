# KYC 106 - deploy check on the current COMMON

COMMON is finished (25 Nov 2026); KYC work starts. This release changes no KYC code: it lets the pipeline deploy KYC
(app 134, schema XXCUS) on the validation database, on top of the COMMON it holds (COMMON 126), and list what fails.

| Issue | Change |
|---|---|
| I-096 (#272) | `repos/kyc/deployment/app.env`: the KYC settings (app 134, XXCUS, workspace XXCUS). |
| I-096 (#272) | Pipeline job **K KYC deploy check** (`repos/common/deployment/db/kyc.sh`), for a `KYC Release <N>: ...` pull request: build COMMON then KYC, import app 134, register KYC in COMMON (`XXFND_ONBOARD_PKG.ONBOARD_SELF` - the grants on the COMMON objects to XXCUS), the KYC database install, the KYC test users (`repos/kyc/db/admin/test-users.sql`, moved from COMMON's test-users.sql - I-097, #274; their APEX accounts are removed first, as COMMON's 5.1a does for its own), import app 134 again, online validation, the KYC DB tests. When the PR also changes COMMON, job K waits for COMMON's jobs 3-8. Every step runs; all failures are reported together in the PR comment. Jobs 9 and 10 wait for it. |

Not in this release: the KYC browser test (after the deploy works), the upgrade test, a KYC release zip.

Each failure the first run reports becomes its own KYC issue; the fixes are the KYC changes on the finished COMMON.
