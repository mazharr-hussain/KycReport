# COMMON 127 - test data: no KYC role codes in COMMON

On top of COMMON 126. Test data and pipeline only; no table, package, page or seed change.

| Issue | Change |
|---|---|
| I-097 (#274) | Found by the KYC deploy check (#273): KYC's install stopped with `ORA-20186: Role REQUESTER belongs to application TDAPP`. COMMON's test data (`db/admin/test-data.json`) registered four of KYC's role codes (REQUESTER, COMPLIANCE_OFFICER, COMPLIANCE_MANAGER, HEAD_OF_COMPLIANCE) for its test application TDAPP; role codes are unique across applications. They are now TD_REQUESTER, TD_OFFICER, TD_MANAGER and TD_HEAD, like every other test row. |
| I-097 (#274) | The test data file has a `removed` list: rows an earlier version of the file loaded and this one no longer has, deleted before the load (`db/load_data.py`, `db/load-data.sql`). It removes the four old roles and their grants from the validation database - only while a role still belongs to TDAPP, so KYC's own roles are never touched. COMMON's role routine (`UNREGISTER_ROLE`) refuses a role that was ever given to a user, and the test users held these. |
| I-097 (#274) | Found by this release's first run (only the fresh install ran - the database scripts are the base's): the pipeline runs COMMON's database scripts before it imports the application, so script 21b found no APEX application to take COMMON's APEX ID from; the DB tests then failed with "Application not found". `db/run.sh` now sets the registered applications' APEX IDs (`XXFND_APPLICATION_PKG.SET_APEX_ID`, as 21b) right after every import. App Builder runs the scripts after the import, so a real install was not affected. |
| I-097 (#274) | Also found by the fresh-install-only run: two test rows relied on the upgrade scripts to complete them (the test data is loaded before the upgrade in job 6, after the install in job 5). The test template TD_TASK_ASSIGNED now has its plain-text message, and the test roles have My Tasks - View (XXFND_ROLE_PRIVILEGES rows), as script 24 gives every role. |
| I-097 (#274) | The COMMON 123 test (`tests/r123_common_test.sql`) changed "any lookup value of an application"; on a fresh install that was a system lookup (level S), whose values cannot be changed (ORA-20130). It now uses a changeable lookup type (level U) and registers its own value first. |
| I-097 (#274) | The KYC test users (TKYC_*) leave COMMON's `db/admin/test-users.sql`; they move to KYC (`repos/kyc/db/admin/test-users.sql`, KYC 106, #273). |

Checked offline: `checks/test_data.py` (27 rows load), the loader's generated SQL, shellcheck, the pipeline dry run.
