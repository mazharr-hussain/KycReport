# COMMON 115 - Code findings R1-R5 and the DB tests for COMMON alone

On top of COMMON 114. The pipeline builds and tests it (jobs 1-6) and job 7.1 exports the tested application as the
release zip (draft release `common-115`, published when job 7.2 merges the PR). Checked offline: build, APEXlang
validation ("Validation successful"), static checks and PMD (0 findings), pipeline lint.

## What changes
| Issue | Where | Change |
|---|---|---|
| I-062 (#221) | `XXFND_APPLICATION_PKG` | `REMOVE_REGISTERED` / `REMOVE_ALL_REGISTERED`: the owner expression joined into the dynamic SQL must be one of the seven expressions COMMON's packages use (allow-list, `OWNER_EXPRESSION`); anything else is refused with ORA-20189 before any SQL runs. No caller changes. |
| I-063 (#222) | Page 100 Modules | Stays unrestricted on purpose (every application's menu opens it with a group code and cannot carry a COMMON checksum; only entries the user may open are shown): the reason is written on the page. |
| I-064 (#223) | `XXFND_APPROVAL_RULE_PKG.STEPS` | The two `SELECT *` list their columns. |
| I-065 (#224) | Page 177 Data Model Diagram | Its CSS moved to the static application file `css/data-model-diagram.css`. |
| I-066 (#225) | `XXFND_APPROVAL_PKG`, `XXFND_RFI_PKG`, `XXFND_INTEGRATION_PKG` | `APPLY_RULES`, `CREATE_RFI` and `DO_CALL` split into smaller private routines (same rules, same errors). |
| I-059 (#217) | DB tests | Option (a): the tests run for COMMON alone - see below. |

## DB tests (I-059, option a)
- `tests/setup/` holds the fixtures, run first by step 6.2: the test applications 860 / 861 and the R89 tables (as
  XXCUS, `-- Schema: XXCUS`), then `03_common_test_fixture.sql`: R86TEST onboarded, the tests' administrator ADMIN
  (Common Administrator and Super Administrator through `BOOTSTRAP_ADMIN`), TEST1; R89 tables left in XXFUSION by an
  earlier run as the wrong schema are dropped.
- Tests that need an administrator's APEX session open one as ADMIN (r109, r110, r111). Creating, reading or locking
  an APEX account outside a browser needs APEX admin rights, so `04_test1_user.sql` (TEST1) and r109 run as the
  database ADMIN in COMMON's schema (`-- Schema: ADMIN`), like the test users of step 6.1.
- r109 reads and locks the account outside the APEX session (APEX refuses it inside one, outside a browser); r86
  counts the re-run's grants of its administrator only (TALL_ACCESS holds every role of every application).
- r81 attaches to the test application's own document entity and text category (registered by the fixture), not to
  whatever setup earlier runs left.
- r110 saves its purposes for the test application R86TEST (COMMON owns no integration purpose); r87_1 checks the
  menu view of release 105 (`XXFND_NAV_MENU_V`).
- Stale checks of routines retired in COMMON 106 ("managed in the application": `IS_MANAGED`, `SAVE_FUNCTIONS`,
  `DELEGATED_URL`, MANAGED menu entries, page 99) are removed; r88 counts seven routines; r89 expects the prefixes
  `XXFND_,XXHR_` (release 102).
- r79: only the test users (ADMIN, TALL_ACCESS) may hold Super Administrator. r83: the Fusion Remote Servers and
  credentials are a workspace prerequisite - skipped where missing. r94: makes a test approval type when none is
  enabled (rolled back); its error line is fixed. r110: an endpoint-less purpose may be refused when saved (CK5).
- r87 parts are numbered in their run order (`r87_1_common`, `r87_2_app` as XXCUS, `r87_3_delete`); the old
  KYC test-user script `tests/test_users.sql` is removed (test users: `db/admin/test-users.sql`, step 6.1).

## Deploy
App Builder > Import the release zip of GitHub Release `common-115` (made by pipeline job 7.1 from the tested
application) over COMMON (135), Install Supporting Objects = Yes. A re-run changes nothing (no table change in this
release). This folder holds only the release notes; the scripts are the application's supporting objects.
