# COMMON deployment pipeline (app 135, schema XXFUSION)

Workflow `.github/workflows/pipeline.yml` (Actions name **COMMON**, one record per PR run). GitHub settings still to
do (tokens, required check, Netlify): `GITHUB-SETUP.md`. Everything it runs lives
in this folder. Before the pipeline, Claude changes the code, reviews it, opens the PR and pushes; the jobs are numbered 1-8.

| Job | Steps | Runs as | Script |
|---|---|---|---|
| 1 Offline validation | 1.0a PR title and linked issues · 1.0 secret scan of the PR's commits (gitleaks) · 1.1 pipeline lint (actionlint, shellcheck) · 1.2 static checks · 1.3 requirements check (warning) · 1.4 build · 1.5 APEXlang LF check + validate · 1.6 PMD (warnings) | no DB | `checks/run.sh`, `checks/pmd.sh` |
| 2 OCI setup | placeholder (OCI infra, vault, DB Tools, IDCS) | - | - |
| 3 DB setup | 3.1 start the DB (placeholder) · 3.2 bootstrap, only when the environment is missing or `bootstrap.sql` changed · 3.3 backup schema `XXFUSION_BKP` (dropped if it exists, created) · 3.4 APEX-SERT installed only when missing or its pinned commit changed | pipeline user; ADMIN for 3.2 | `db/run.sh setup` |
| 4 Deploy fresh app | 4.0 back up the app's data · 4.1 remove app + DB objects · 4.2 deploy this version · 4.3 online validation · 4.4 dependency check: deployed schema vs the generated map (report) | pipeline user / proxy | `db/run.sh fresh` |
| 5 Upgrade app | 5.1 remove (= 4.1) · 5.2 deploy the last release (= 4.2, the PR's base commit) · 5.3 restore the data + snapshot · 5.4 upgrade to this version (once) · 5.5 nothing lost · 5.6 online validation (= 4.3) · 5.7 drop the backup schema | pipeline user / proxy | `db/run.sh upgrade <base>` |
| 6 Testing and validation | 6.1 test users · 6.2 DB tests: `tests/setup` fixtures first, then the feature tests and `tests/*.sql`; a `-- Schema: <NAME>` line runs a file as that schema (any FAIL / ORA- / PLS- fails the job) · 6.3 browser smoke test: each test user opens every page (Playwright: video, screenshots, trace; an error page fails it) · 6.4 APEX-SERT evaluation (report) · 6.5 DBSAT (report; when its download is set) · 6.6 OWASP ZAP baseline scan (report) | ADMIN for 6.1, 6.4, 6.5; proxy for 6.2 | `db/run.sh test`, `ui/smoke_ui.py`, ZAP action |
| 7 Finalize the PR | gate (every earlier job passed) · 7.1 APEXlang export of the tested app -> zip (artifact; draft GitHub Release when the PR adds a release) · 7.2 issues for the existing findings (future releases), then merge (ready for review if draft; label `hold` stops it) and publish the release · 7.3 readable APEX docs (`READABLE_YAML` export) · 7.4 database docs (SchemaSpy) - both artifacts and on the draft release | proxy | `db/run.sh finalize <dir>`, `checks/issues.py`, `release/merge.sh` |
| 8 Error handling | only on a failure: job, step, errors and log tail -> PR comment (3 retries) and run summary; the pipeline stops, the PR stays open | - | in the workflow |

**Naming (issue #218):** PR title `<APP> Release <Number>: <short summary>` (APP = COMMON / KYC, summary at most 60
characters); the issues of the release are linked in the PR body with one `Fixes #n` line each (GitHub lists them under
the PR's Development and closes them on merge). Each push starts one run named `<PR title>: Push Number <N>` (N = the
PR's commit count - Claude pushes one commit per push); a retry of the same push stays in that run (attempt 2, 3, ...).
Job 1.0a checks the title and the linked issues; the release number comes from the title.

**Annotations:** only findings in the files a PR changes become GitHub warning annotations (1.2 static checks, 1.6
PMD); findings in unchanged files are existing code and are listed in the step log as `existing: ...`, with a count.
Information (PMD files it cannot parse, the dependency report, the restore report, DBSAT not set up) is logged as
`info: ...`, never annotated. **PR comment:** every run posts one comment on the PR - "passed" (job 7) or the error
(job 8) - with the warnings in this change, the notices and the existing findings (collapsed), built by
`checks/report.py` from the step logs. **Issues:** a pipeline failure or a warning in the PR's own files is never an
issue - it is fixed in the PR from that comment (the next push). Only the existing findings (files the PR did not
change) belong to a future release: on a green run, job 7.2 (`checks/issues.py`) creates one COMMON issue per finding
(file + rule, line numbers left out; a marker in the body stops duplicates) and add-to-project.yml puts it on the board;
the comment lists the issues created. A change to the pipeline itself (this folder or the workflow files) goes straight to
`main` without a PR (CLAUDE.md).

Any failing step stops its job; every later job is skipped. Job 7 always runs its gate, which fails with "7 Finalize the PR stopped because of job <x> failure"; job 8 then reports "COMMON pipeline failed because of job <x> failure" (step, errors, skipped jobs) on the PR and stops the pipeline.

## What the pipeline does so nobody repeats it by hand (agreed 3 Nov 2026)
Claude changes the code and reviews it; every fixed, repeated step is here:
- **Source map** (1.1b, `checks/source_map.py`): new / removed application files are registered in
  `repos/common/SOURCE-MAP.json` for the build.
- **Build with the release number** (1.4): "Release N" from the PR title is stamped into the application; jobs 4-5
  deploy the database scripts of this build (artifact `common-deploy`), not committed copies.
- **Generated files** (`release/regenerate.sh`): after the merge (7.2), and after any push to `main` made by a person
  (`generated-files.yml`), SOURCE-MAP.json, `db/deploy` and `docs/components/*/technical.md` are rebuilt and committed
  to `main`. They are never committed by hand.
- **Release**: 7.1 exports the tested application as the release zip; a release folder `repos/common/releases/<N>-*/`
  holds only its README (the release notes).
- **ISSUES.md** (`issues-sync.yml`, `release/issues_md.py`): a new COMMON / KYC issue gets its row, a closed one moves
  to Fixed.
- **Pipeline-only pushes to `main`** (`pipeline-check.yml`): step 1.1 (actionlint, shellcheck, Python compile) checks
  them on `main`; a failure shows on the commit and is fixed by the next push.

**Faster re-pushes (agreed 3 Nov 2026):**
- **All test failures at once (A):** job 6 runs every test step even after one fails (`KEEP_GOING`), and ZAP still
  runs; the job fails at the end and job 8 reports every failed step in one PR comment.
- **Skip the deploy when nothing to deploy changed (B):** job 1 fingerprints the built application and database
  scripts; 5.8 records the fingerprint of a version that passed its fresh install and upgrade test (`db/deployed.sql`,
  table `XXCI_DEPLOYED` of the pipeline user). When the database already holds this fingerprint (a push that changes
  only tests, docs or the pipeline), 3.2b says so and jobs 4-5 are skipped - job 6 tests straight away.
- **DB tests on the fresh install (C):** 4.5 test users and 4.6 DB tests run right after the fresh install, so a test
  failure stops the run before the upgrade test; job 6 runs them again on the upgraded data.
- **Caches (D):** PMD (job 1) and Playwright's Chromium (job 6) are cached between runs.

**Runner image:** every workflow runs on `ubuntu-24.04` (pinned, not `ubuntu-latest`, which GitHub moves to Ubuntu 26
from 19 Oct 2026): the tools (SQLcl, Playwright, Instant Client) are set up on that image. Moving to a newer image is
a one-line change per workflow, made on purpose and tested by a run.

## Files
| File | Purpose |
|---|---|
| `app.env` | the application: id, schema, backup schema, workspace, pipeline user, tables never restored, URL path, browser-test users |
| `tools.env` | pinned tools with their SHA-256: gitleaks, SchemaSpy, Oracle JDBC, Instant Client (DBSAT), Playwright, APEX-SERT commit |
| `lib/fetch.sh`, `lib/app-url.sh` | checksum-verified download; the APEX URL read from the wallet (or `VAL_APP_URL`) |
| `ui/smoke_ui.py` | browser smoke test (6.3) |
| `db/dependencies.sql`, `db/compare_dependencies.py` | dependency check (4.4) |
| `db/sert-eval.sql` | APEX-SERT evaluation (6.4) |
| `lib/sql.sh` | SQLcl login to the validation ADB: wallet; connect line on stdin (never on the command line or in a file) |
| `release/regenerate.sh`, `release/issues_md.py`, `checks/source_map.py` | generated files to `main`; ISSUES.md rows; SOURCE-MAP in step |
| `release/merge.sh`, `release/publish.sh` | 7.2 merge of the green PR; publish its GitHub Release (also used by release.yml) |
| `checks/report.py`, `checks/issues.py` | the PR comment's report; issues for the existing findings |
| `lib/step.sh` | step logging, step summary, failure record for job 8 |
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
  3.2 bootstrap and 6.1 test users (creating APEX accounts outside
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
Job 7.1 builds the zip from the application that passed jobs 4-6 (SQLcl `apex export -exptype APEXLANG`) and puts it,
with the docs, into the draft GitHub Release `common-<N>` (N from the PR title; notes: the title and the linked
issues, plus `repos/common/releases/<N>-*/README.md` when the PR has one). Job 7.2 merges the PR and publishes the release
(`release/publish.sh`); `release.yml` runs the same script when a person merges a PR by hand.

## Run locally
Set `SQL`, `WALLET`, `VAL_DB_SERVICE`, `ADMIN_PW` (and `XXCUS_PW` for setup, `PMD` for 1.6), then
`bash checks/run.sh`, `bash db/run.sh setup`, `bash db/run.sh fresh`, `bash db/run.sh upgrade origin/main`,
`bash db/run.sh test`.
