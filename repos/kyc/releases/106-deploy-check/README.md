# KYC 106 - deploy check on the current COMMON

COMMON is finished (25 Nov 2026); KYC work starts. This release changes no KYC code: it lets the pipeline deploy KYC
(app 134, schema XXCUS) on the validation database, on top of the COMMON it holds (COMMON 126), and list what fails.

| Issue | Change |
|---|---|
| I-096 (#272) | `repos/kyc/deployment/app.env`: the KYC settings (app 134, XXCUS, workspace XXCUS). |
| I-096 (#272) | Pipeline job **K KYC deploy check** (`repos/common/deployment/db/kyc.sh`), for a `KYC Release <N>: ...` pull request: build COMMON then KYC, import app 134, register KYC in COMMON (`XXFND_ONBOARD_PKG.ONBOARD_SELF` - the grants on the COMMON objects to XXCUS), the KYC database install, the KYC test users (`repos/kyc/db/admin/test-users.sql`, moved from COMMON's test-users.sql - I-097, #274; their APEX accounts are removed first, as COMMON's 5.1a does for its own), import app 134 again, online validation, the KYC DB tests. When the PR also changes COMMON, job K waits for COMMON's jobs 3-8. Every step runs; all failures are reported together in the PR comment. Jobs 9 and 10 wait for it. |

## KYC tests on the current COMMON (found by job K)

| Issue | Change |
|---|---|
| I-098 (#276) | The KYC DB tests' users (REQ1, REQ2, OFFICER1, MGR1, HOC1) are made by `repos/kyc/db/admin/test-users.sql` (step K.3a); they came from `apex/tests/test_users.sql`, which never moved to `repos/` (`security_test.sql` and `workflow_test.sql` included it). |
| I-099 (#277) | `r76_kyc_test.sql` and `workflow_test.sql` no longer use the old test helper `XXFND_TEST_FIXTURE_PKG`: approval rules, role grants and delegations are switched with COMMON's routines (COMMON 123: `SET_RULE_ENABLED`, `SET_ROLE_ENABLED`, `ADD_DELEGATION` / `END_DELEGATION`). |
| I-100 (#278) | `kyc88_shared_test.sql` follows the design since release 88: page 100 is KYC's Administration page again (release 95), COMMON page 99 is gone, the side menu and the navigation bar are COMMON's subscribed lists built by `XXFND_NAV_PKG` (release 104 / 105). The KYC administrator's menu is checked as TKYC_ADMIN; a page without a KYC feature is named in the result. |
| I-101 (#279) | The data-security refusal (ORA-28115) came from OFFICER1 not existing - fixed with #276. |
| I-102 (#280) | `kyc90_cleanup_test.sql`: page 206 has 8 decision buttons with `CAN_DECIDE` (KYC 105 added a copy of each at the top), not 6. |

| I-098 (#276) | Second run: since KYC 104 the requesting department is an ID (XXHR_ORGANIZATIONS), not a code - the tests passed 'FINANCE' / 'PROCUREMENT' (ORA-06502). `test-users.sql` now makes the two departments through COMMON's `XXFND_VPD_PKG.SAVE_ORGANIZATION` (KYC's), and the tests look up their IDs. `r74_email_test.sql` says so when there is no case to send from; `workflow_test.sql` switches COMMON's CONFIG_CHANGE process on for KYC (onboarding starts it off) and waits for the task the workflow creates in the background. |
| I-098 (#276) | Third run: the requesting country is required since KYC 105 (ORA-20611) - the tests pass 'AE'. `workflow_test.sql` no longer switches CONFIG_CHANGE (not a KYC process; the task is made anyway) and leaves out "REQ2 does not see REQ1's task" while a REQ1 -> REQ2 delegation of an earlier run today is still active (#281). |
| I-098 (#276) | Fourth run: the CORPORATE questionnaire has a sixth required question since KYC 99 ("Business counterparty ownership structure type") - kyc_flow, r75 and r76 answer it; r73 makes its own person party for the beneficial-owner check (a fresh install has none). token_test and workflow_test print what OFFICER1 holds and the RFI data security predicate (INFO lines) - an ORA-28115 on the RFI insert is being traced. |
| I-098 (#276) | Fifth run (178 passed, 7 failed): the tests expected the request statuses before KYC 105 - Submit now gives Submitted (waiting for Assign), a request that needs no KYC closes as KYC Not Required, and a case opened at once makes it Under Review - which KYC 105's own notes listed as "not changed in this release". `kyc_flow_test.sql` and `r76_kyc_test.sql` expect the new statuses; since KYC 99 a requester sees the party he created, so the party-master check says so. `r74_email_test.sql` checks the kept RFI e-mail only when one was sent (the sender address is a COMMON setting a KYC session cannot set). |
| I-100 (#278) | Page 100 (Administration, any administrator) belongs to no single feature, like the global page: left out of the "every page belongs to a feature" check. |

Job K prints the whole output of each failing test file.

Not in this release: the KYC browser test (after the deploy works), the upgrade test, a KYC release zip.

Each failure the first run reports becomes its own KYC issue; the fixes are the KYC changes on the finished COMMON.
