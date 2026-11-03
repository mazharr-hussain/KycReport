# COMMON deployment pipeline (app 135, schema XXFUSION)

Workflow `.github/workflows/pipeline.yml` (Actions name **COMMON**, one record per PR run). GitHub settings still to
do (tokens, required check, Netlify): `GITHUB-SETUP.md`. Everything it runs lives
in this folder. Steps 1-2 happen before the pipeline: Claude changes the code, reviews it, opens the PR and pushes.

| Job | Steps | Runs as | Script |
|---|---|---|---|
| 3 Offline validation | 3.0a PR title and linked issues · 3.0 secret scan of the PR's commits (gitleaks) · 3.1 pipeline lint (actionlint, shellcheck) · 3.2 static checks · 3.3 requirements check (warning) · 3.4 build · 3.5 APEXlang LF check + validate · 3.6 PMD (warnings) | no DB | `checks/run.sh`, `checks/pmd.sh` |
| 4 OCI setup | placeholder (OCI infra, vault, DB Tools, IDCS) | - | - |
| 5 DB setup | 5.1 start the DB (placeholder) · 5.2 bootstrap, only when the environment is missing or `bootstrap.sql` changed · 5.3 backup schema `XXFUSION_BKP` (dropped if it exists, created) · 5.4 APEX-SERT installed only when missing or its pinned commit changed | pipeline user; ADMIN for 5.2 | `db/run.sh setup` |
| 6 Deploy fresh app | 6.0 back up the app's data · 6.1 remove app + DB objects · 6.2 deploy this version · 6.3 online validation · 6.4 dependency check: deployed schema vs the generated map (report) | pipeline user / proxy | `db/run.sh fresh` |
| 7 Upgrade app | 7.1 remove (= 6.1) · 7.2 deploy the last release (= 6.2, the PR's base commit) · 7.3 restore the data + snapshot · 7.4 upgrade to this version (once) · 7.5 nothing lost · 7.6 online validation (= 6.3) · 7.7 drop the backup schema | pipeline user / proxy | `db/run.sh upgrade <base>` |
| 8 Testing and validation | 8.1 test users · 8.2 DB tests: `tests/setup` fixtures first, then the feature tests and `tests/*.sql`; a `-- Schema: <NAME>` line runs a file as that schema (any FAIL / ORA- / PLS- fails the job) · 8.3 browser smoke test: each test user opens every page (Playwright: video, screenshots, trace; an error page fails it) · 8.4 APEX-SERT evaluation (report) · 8.5 DBSAT (report; when its download is set) · 8.6 OWASP ZAP baseline scan (report) | ADMIN for 8.1, 8.4, 8.5; proxy for 8.2 | `db/run.sh test`, `ui/smoke_ui.py`, ZAP action |
| 9 Finalize the PR | gate (every earlier job passed) · 9.1 APEXlang export of the tested app -> zip (artifact; draft GitHub Release when the PR adds a release) · 9.2 issues for the existing findings (future releases), then merge (ready for review if draft; label `hold` stops it) and publish the release · 9.3 readable APEX docs (`READABLE_YAML` export) · 9.4 database docs (SchemaSpy) - both artifacts and on the draft release | proxy | `db/run.sh finalize <dir>`, `checks/issues.py`, `release/merge.sh` |
| 10 Error handling | only on a failure: job, step, errors and log tail -> PR comment (3 retries) and run summary; the pipeline stops, the PR stays open | - | in the workflow |

**Naming (issue #218):** PR title `<APP> Release <Number>: <short summary>` (APP = COMMON / KYC, summary at most 60
characters); the issues of the release are linked in the PR body with one `Fixes #n` line each (GitHub lists them under
the PR's Development and closes them on merge). Each push starts one run named `<PR title>: Push Number <N>` (N = the
PR's commit count - Claude pushes one commit per push); a retry of the same push stays in that run (attempt 2, 3, ...).
Job 3.0a checks the title and the linked issues; the release number comes from the title.

**Annotations:** only findings in the files a PR changes become GitHub warning annotations (3.2 static checks, 3.6
PMD); findings in unchanged files are existing code and are listed in the step log as `existing: ...`, with a count.
Information (PMD files it cannot parse, the dependency report, the restore report, DBSAT not set up) is logged as
`info: ...`, never annotated. **PR comment:** every run posts one comment on the PR - "passed" (job 9) or the error
(job 10) - with the warnings in this change, the notices and the existing findings (collapsed), built by
`checks/report.py` from the step logs. **Issues:** a pipeline failure or a warning in the PR's own files is never an
issue - it is fixed in the PR from that comment (the next push). Only the existing findings (files the PR did not
change) belong to a future release: on a green run, job 9.2 (`checks/issues.py`) creates one COMMON issue per finding
(file + rule, line numbers left out; a marker in the body stops duplicates) and add-to-project.yml puts it on the board;
the comment lists the issues created. A change to the pipeline itself (this folder or the workflow files) goes straight to
`main` without a PR (CLAUDE.md).

Any failing step stops its job; every later job is skipped. Job 9 always runs its gate, which fails with "9 Finalize the PR stopped because of job <x> failure"; job 10 then reports "COMMON pipeline failed because of job <x> failure" (step, errors, skipped jobs) on the PR and stops the pipeline.

## Files
| File | Purpose |
|---|---|
| `app.env` | the application: id, schema, backup schema, workspace, pipeline user, tables never restored, URL path, browser-test users |
| `tools.env` | pinned tools with their SHA-256: gitleaks, SchemaSpy, Oracle JDBC, Instant Client (DBSAT), Playwright, APEX-SERT commit |
| `lib/fetch.sh`, `lib/app-url.sh` | checksum-verified download; the APEX URL read from the wallet (or `VAL_APP_URL`) |
| `ui/smoke_ui.py` | browser smoke test (8.3) |
| `db/dependencies.sql`, `db/compare_dependencies.py` | dependency check (6.4) |
| `db/sert-eval.sql` | APEX-SERT evaluation (8.4) |
| `lib/sql.sh` | SQLcl login to the validation ADB: wallet; connect line on stdin (never on the command line or in a file) |
| `release/merge.sh`, `release/publish.sh` | 9.2 merge of the green PR; publish its GitHub Release (also used by release.yml) |
| `checks/report.py`, `checks/issues.py` | the PR comment's report; issues for the existing findings |
| `lib/step.sh` | step logging, step summary, failure record for job 10 |
| `db/bootstrap.sql` | users, pipeline user and its privileges, workspace, App Builder user, REST-enabled schemas (ADMIN) |
| `db/ci-password.sql` | new random password of the pipeline user for each job (ADMIN) |
| `db/needs-bootstrap.sql` | is the environment complete? (pipeline user, read only) |
| `db/backup-schema.sql` | drop / create the backup schema (refuses any name not ending in `_BKP`) |
| `db/grant-to.sql`, `db/backup.sql`, `db/restore.sql`, `db/compare.sql` | upgrade test: copy the app's data, put it back into the old release, compare after the upgrade |
| `db/remove-app.sql`, `db/clear-schema.sql` | remove the application and every object of the schema (validation DB only) |
| `db/validate-online.sql` | no invalid object / compile error; application installed, available, every page present |

## Users on the validation database
- **Pipeline user `XXCI_DEPLOY`** (no stored password: every database job gives it a new random password as ADMIN,
  masked in the logs - `db/ci-password.sql`): create session / create table (with admin option, for
  the backup schema), create / alter / drop user (backup schema), `APEX_ADMINISTRATOR_ROLE` (remove / export the app);
  connects through XXFUSION and XXCUS as a proxy (`XXCI_DEPLOY[XXFUSION]`).
- **ADMIN** (secret `VAL_DB_ADMIN_PASSWORD`) only for the pipeline user's password at the start of each database job,
  5.2 bootstrap and 8.1 test users (creating APEX accounts outside
  an APEX session needs APEX instance rights for the session user).

Secrets (environment "Oracle DB Dev"): `VAL_DB_WALLET`, `VAL_DB_SERVICE`, `VAL_DB_ADMIN_PASSWORD`,
`VAL_DB_PASSWORD` (App Builder user XXCUS). Passwords must not contain a double quote.

## Reports (artifacts of each run)
| Artifact | Contents |
|---|---|
| `report-6-dependencies` | live dependencies (CSV) and `dependency-check.md` |
| `report-8-test` | `ui/<user>/` video, screenshots of every page, `trace.zip` (open with `playwright show-trace`), `results.json`; `apex-sert-findings.csv` + summary; `dbsat/` (when set up) |
| `report-8-zap` | OWASP ZAP baseline report (HTML, JSON, Markdown) |
| `common-docs` | `COMMON-apex-docs.zip` (readable YAML of every page) and `COMMON-db-docs.zip` (SchemaSpy HTML) |
| `common-release-zip` | the importable APEXlang zip of the tested application |

## Releases
Job 9.1 builds the zip from the application that passed jobs 6-8 (SQLcl `apex export -exptype APEXLANG`) and puts it,
with the docs, into the draft GitHub Release `common-<N>` (N from the PR title; notes: the title and the linked
issues, plus `repos/common/releases/<N>-*/README.md` when the PR has one). Job 9.2 merges the PR and publishes the release
(`release/publish.sh`); `release.yml` runs the same script when a person merges a PR by hand.

## Run locally
Set `SQL`, `WALLET`, `VAL_DB_SERVICE`, `ADMIN_PW` (and `XXCUS_PW` for setup, `PMD` for 3.6), then
`bash checks/run.sh`, `bash db/run.sh setup`, `bash db/run.sh fresh`, `bash db/run.sh upgrade origin/main`,
`bash db/run.sh test`.
