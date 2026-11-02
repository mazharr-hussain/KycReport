# COMMON deployment pipeline (app 135, schema XXFUSION)

Workflow `.github/workflows/pipeline.yml` (Actions name **COMMON**, one record per PR run). Everything it runs lives
in this folder. Steps 1-2 happen before the pipeline: Claude changes the code, reviews it, opens the PR and pushes.

| Job | Steps | Runs as | Script |
|---|---|---|---|
| 3 Offline validation | 3.1 pipeline lint (actionlint, shellcheck) · 3.2 static checks · 3.3 requirements check (warning) · 3.4 build · 3.5 APEXlang LF check + validate · 3.6 PMD (warnings) | no DB | `checks/run.sh`, `checks/pmd.sh` |
| 4 OCI setup | placeholder (OCI infra, vault, DB Tools, IDCS) | - | - |
| 5 DB setup | 5.1 start the DB (placeholder) · 5.2 bootstrap, only when the environment is missing or `bootstrap.sql` changed · 5.3 backup schema `XXFUSION_BKP` (dropped if it exists, created) | pipeline user; ADMIN for 5.2 | `db/run.sh setup` |
| 6 Deploy fresh app | 6.0 back up the app's data · 6.1 remove app + DB objects · 6.2 deploy this version · 6.3 online validation | pipeline user / proxy | `db/run.sh fresh` |
| 7 Upgrade app | 7.1 remove (= 6.1) · 7.2 deploy the last release (= 6.2, the PR's base commit) · 7.3 restore the data + snapshot · 7.4 upgrade to this version (once) · 7.5 nothing lost · 7.6 online validation (= 6.3) · 7.7 drop the backup schema | pipeline user / proxy | `db/run.sh upgrade <base>` |
| 8 Testing and validation | 8.1 test users · 8.2 DB tests (any FAIL / ORA- / PLS- fails the job) | ADMIN for 8.1, proxy for 8.2 | `db/run.sh test` |
| 9 Finalize the PR | gate (every earlier job passed) · 9.1 APEXlang export of the tested app -> zip (artifact; draft GitHub Release when the PR adds a release) · 9.2 merge: GitHub auto-merge completes it when this required check is green | proxy | `db/run.sh export <dir>` |
| 10 Error handling | only on a failure: job, step, errors and log tail -> PR comment (3 retries) and run summary; the pipeline stops, the PR stays open | - | in the workflow |

Any failing step stops its job; every later job is skipped (job 9 runs only its gate, which fails) and job 10 reports.

## Files
| File | Purpose |
|---|---|
| `app.env` | the application: id, schema, backup schema, workspace, pipeline user, tables never restored |
| `lib/sql.sh` | SQLcl login to the validation ADB: wallet; connect line on stdin (never on the command line or in a file) |
| `lib/step.sh` | step logging, step summary, failure record for job 10 |
| `db/bootstrap.sql` | users, pipeline user and its privileges, workspace, App Builder user, REST-enabled schemas (ADMIN) |
| `db/needs-bootstrap.sql` | is the environment complete? (pipeline user, read only) |
| `db/backup-schema.sql` | drop / create the backup schema (refuses any name not ending in `_BKP`) |
| `db/grant-to.sql`, `db/backup.sql`, `db/restore.sql`, `db/compare.sql` | upgrade test: copy the app's data, put it back into the old release, compare after the upgrade |
| `db/remove-app.sql`, `db/clear-schema.sql` | remove the application and every object of the schema (validation DB only) |
| `db/validate-online.sql` | no invalid object / compile error; application installed, available, every page present |

## Users on the validation database
- **Pipeline user `XXCI_DEPLOY`** (secret `VAL_DB_CI_PASSWORD`): create session / create table (with admin option, for
  the backup schema), create / alter / drop user (backup schema), `APEX_ADMINISTRATOR_ROLE` (remove / export the app);
  connects through XXFUSION and XXCUS as a proxy (`XXCI_DEPLOY[XXFUSION]`).
- **ADMIN** (secret `VAL_DB_ADMIN_PASSWORD`) only for 5.2 bootstrap and 8.1 test users (creating APEX accounts outside
  an APEX session needs APEX instance rights for the session user).

Secrets (environment "Oracle DB Dev"): `VAL_DB_WALLET`, `VAL_DB_SERVICE`, `VAL_DB_ADMIN_PASSWORD`,
`VAL_DB_CI_PASSWORD`, `VAL_DB_PASSWORD` (App Builder user XXCUS). Passwords must not contain a double quote.

## Releases
Job 9.1 builds the zip from the application that passed jobs 6-8 (SQLcl `apex export -exptype APEXLANG`). When the PR
adds `repos/common/releases/<N>-<name>/README.md`, the zip goes into a draft GitHub Release `common-<N>`;
`release.yml` publishes it when the PR merges (the only workflow that publishes releases).

## Run locally
Set `SQL`, `WALLET`, `VAL_DB_SERVICE`, `CI_PW` (and `ADMIN_PW`, `XXCUS_PW` for setup / test, `PMD` for 3.6), then
`bash checks/run.sh`, `bash db/run.sh setup`, `bash db/run.sh fresh`, `bash db/run.sh upgrade origin/main`,
`bash db/run.sh test`.
