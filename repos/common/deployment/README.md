# COMMON deployment pipeline (app 135, schema XXFUSION)

Workflow `.github/workflows/pipeline.yml` (Actions name **COMMON**, one record per PR run). GitHub settings still to
do (tokens, required check, Netlify): `GITHUB-SETUP.md`. Everything it runs lives
in this folder. Before the pipeline, Claude changes the code, reviews it, opens the PR and pushes; the jobs are numbered 1-8.

| Job | Steps | Runs as | Script |
|---|---|---|---|
| 1 Offline validation | 1.0 PR title and linked issues (a Dependabot PR: 1.0 its workflow files only) · 1.0a secret scan of the PR's commits (gitleaks) · 1.1 pipeline lint (actionlint, shellcheck, decision self-test, dry run of every database-job path - `checks/dryrun.sh`) · 1.1a SOURCE-MAP in step · 1.2 static checks · 1.3 requirements check (warning) · 1.4 build · 1.5 APEXlang LF check + validate · 1.6 PMD (warnings) · 1.6a test data fits the install (skipped without a test data file) · 1.9 generated technical docs up to date (notice; 9.2a adds them) - 1.1a to 1.6a and 1.9 follow the app parameter (`APP_DIR`): COMMON and KYC · KYC's older 1.7 (install safety and golden rules, a copy of 1.2) still runs beside 1.2 | no DB | `checks/run.sh`, `checks/pmd.sh` |
| 2 OCI setup | placeholder (OCI infra, vault, DB Tools, IDCS) | - | - |
| 3 DB setup | 3.0 new password of the pipeline user · 3.1 start the DB (placeholder) · 3.2 bootstrap, only when the environment is missing or `bootstrap.sql` changed · 3.2a deploy decision (`db/decide.py`: reuse / app / patch / upgrade / loaded / data / retest / full) · 3.3 drop the backup schemas of earlier pipelines (once; no backup schema since I-076) · 3.4 APEX-SERT installed only when missing or its pinned commit changed - full validation only (I-075) · 3.5 prerequisites: what `REQUIRES` in the app's `app.env` names (KYC: COMMON) must be installed, and the app registered in it (`ONBOARD_SELF` when not); COMMON has none (I-106) | pipeline user; ADMIN for 3.0, 3.2 | `db/run.sh setup` |
| 4 Quick check (patch only) | 4.0 new password · 4.Q0 version guard · 4.Q1 mark the record · 4.Q2 run the changed code objects alone · 4.Q3 import the app (when it changed) · 4.Q4 online validation · 4.Q5 record (PATCH) · 4.Q6 select the tests of the changed objects and their callers · 4.Q7 those DB tests · 4.Q8 record the failed files; a pass is followed by jobs 5-8 in the same run | proxy | `db/run.sh quick` |
| 5 Deploy fresh app | 5.0 new password · 5.0a guard (app only / loaded / data) · 5.0b mark the record · 5.1 remove the app and only its own DB objects (I-077: never the schema or other apps' objects) · 5.1a remove the test users' APEX accounts · 5.2 deploy this version · 5.2a record the install · 5.2b load this version's test data (`db/admin/test-data.json`) · 5.2c record it loaded · 5.3 online validation · 5.4 dependency check: deployed schema vs the generated map (report) · 5.5 record the fresh install's structure · 5.6 record the version (app only, or no upgrade test) | pipeline user / proxy | `db/run.sh fresh` |
| 6 Upgrade app | 6.0 new password · 6.0a guard (upgrade / upgraded only) · 6.0b mark the record · 6.1 remove (= 5.1) · 6.2 build and 6.2a deploy the last release (the PR's base commit) · 6.3 load the last release's test data (its own file from git) · 6.4 snapshot of the app's tables (row counts, rows by key) to a file and the database (no backup schema, I-076) · 6.5 upgrade to this version (once) · 6.5a record it upgraded · 6.6 nothing lost (snapshot before / after) + every key checked against the old rows · 6.7 load this version's test data again (insert + update: the delta) · 6.8 same structure as the fresh install · 6.9 online validation · 6.10 record the version. Skipped when the DB scripts equal the base's (F) or the app has no release yet (I-076) | pipeline user / proxy | `db/run.sh upgrade <base>` |
| 7 DB tests and security | 7.0 new password · 7.0a version guard · retest only: 7.0b load the test data, 7.0c what the tests rely on · 7.1 select the DB tests (reuse / app: what changed since the last tested commit + last failures) · 7.2 DB tests (every expected file must run): `tests/setup` fixtures first, then the feature tests and `tests/*.sql`; a `-- Schema: <NAME>` line runs a file as that schema (any FAIL / ORA- / PLS- fails the job) · 7.2a record the failed files · 7.3 record the version (retest only) · 7.4 APEX-SERT evaluation (report) · 7.5 DBSAT (report; when its download is set) - 7.4-7.5 in the full validation only (I-075) | ADMIN for 7.4, 7.5; proxy for 7.2 | `db/run.sh test` |
| 8 Browser test and ZAP | 8.0 version guard · 8.1 test users · 8.2 their password of this run · 8.3 browser smoke test: each test user opens every page (Playwright: video, screenshots, trace; an error page fails it) · 8.3a the errors the application logged meanwhile (page, user, message - notices, I-067) · 8.4 OWASP ZAP baseline scan (report; full validation only) | ADMIN for 8.1 | `db/run.sh ui`, `ui/smoke_ui.py`, ZAP action |
| 9 Finalize the PR | gate (every earlier job passed) · 9.0 new password · 9.0a version guard · 9.1 APEXlang export of the tested app -> zip (artifact) · 9.1a draft GitHub Release (when the PR adds a release) · 9.2 issues for the existing findings (future releases) · 9.2a the PR carries its generated files · 9.2b auto-merge (full validation only; label `hold` stops it - a draft PR: not merged) - the release stays a draft (I-091) · 9.2c report on the PR · 9.3 documentation: 9.3a readable APEX docs (`READABLE_YAML` export), 9.3b database docs (SchemaSpy) - both artifacts and on the draft release | proxy | `db/run.sh finalize <dir>`, `checks/issues.py`, `release/merge.sh` |
| 8 Browser test and ZAP | 8.0 version guard · 8.1 test users · 8.2 their password of this run · 8.3 browser smoke test: each test user opens every page (Playwright: video, screenshots, trace; an error page fails it) · 8.4 OWASP ZAP baseline scan (report; full validation only) | ADMIN for 8.1 | `db/run.sh ui`, `ui/smoke_ui.py`, ZAP action |
| 9 Finalize the PR | gate (every earlier job passed) · 9.0 new password · 9.0a version guard · 9.1 APEXlang export of the tested app -> zip (artifact) · 9.1a draft GitHub Release (when the PR adds a release) · 9.2 issues for the existing findings (future releases) · 9.2a the PR carries its generated files · 9.2b auto-merge (label `hold` stops it; a draft PR runs nothing, I-094) - the release stays a draft (I-091) · 9.2c report on the PR · 9.3 documentation: 9.3a readable APEX docs (`READABLE_YAML` export), 9.3b database docs (SchemaSpy) - both artifacts and on the draft release | proxy | `db/run.sh finalize <dir>`, `checks/issues.py`, `release/merge.sh` |
| 10 Error handling | only on a failure: job, step, errors and log tail -> PR comment (3 retries) and run summary; sets the label `start-from-N` (N = 5, 6 or 7: the failed job) so the next push resumes there (I-105; not for a temporary failure; job 3 follows it only when its records allow, job 9 clears it); the pipeline stops, the PR stays open | - | in the workflow |

**Naming (issue #218):** PR title `<APP> Release <Number>: <short summary>` (APP = COMMON / KYC, summary at most 60
characters); the issues of the release are linked in the PR body with one `Fixes #n` line each (GitHub lists them under
the PR's Development and closes them on merge). Each push starts one run named `<PR title>: Push Number <N>` (N = the
PR's commit count - Claude pushes one commit per push); a retry of the same push stays in that run (attempt 2, 3, ...).
Job 1.0 checks the title and the linked issues; the release number comes from the title.

**Annotations:** only findings in the files a PR changes become GitHub warning annotations (1.2 static checks, 1.6
PMD); findings in unchanged files are existing code and are listed in the step log as `existing: ...`, with a count.
Information (PMD files it cannot parse, the dependency report, test data left out on the old structure, DBSAT not set up) is logged as
`info: ...`, never annotated. **PR comment:** every run posts one comment on the PR - "passed" (job 9) or the error
(job 10) - with the warnings in this change, the notices and the existing findings (collapsed), built by
`checks/report.py` from the step logs. **Issues:** a pipeline failure or a warning in the PR's own files is never an
issue - it is fixed in the PR from that comment (the next push). Only the existing findings (files the PR did not
change) belong to a future release: on a green run, job 9.2 (`checks/issues.py`) creates one COMMON issue per finding
(file + rule, line numbers left out; a marker in the body stops duplicates) (no workflow puts it on a board since I-091 - added by hand);
the comment lists the issues created. A change to the pipeline itself (this folder or the workflow files) goes straight to
`main` without a PR (CLAUDE.md).

Any failing step stops its job; every later job is skipped. Job 9 always runs its gate, which fails with "9 Finalize the PR stopped because of job <x> failure" (or "cancelled"); job 10 then reports "COMMON pipeline stopped: job <x> failed" - or "was cancelled (its time limit, or stopped by hand)" - with the step, errors and skipped jobs on the PR, and stops the pipeline. A run stopped because a newer push replaced it (`control.yml`) only gets a note in its run summary, no PR comment. The PR comment also holds a collapsed **step-time table** (each scripted step's time, slowest first, and each job's total - `lib/step.sh` writes `timings`, `checks/report.py` builds the table).

## What the pipeline does so nobody repeats it by hand (agreed 3 Nov 2026)
Claude changes the code and reviews it; every fixed, repeated step is here:
- **Source map** (1.1a, `checks/source_map.py`): new / removed application files are registered in
  `repos/common/SOURCE-MAP.json` for the build.
- **Build with the release number** (1.4): "Release N" from the PR title is stamped into the application; jobs 5-6
  deploy the database scripts of this build (artifact `common-deploy`), not committed copies.
- **Generated files come in the PR (9.2a, `release/carry.sh`):** `main` takes pull requests only, so
  nothing is pushed to it by itself. When a full validation passes, job 9 rebuilds SOURCE-MAP.json, `db/deploy` and
  `docs/components/*/technical.md`. If anything differs it pushes one commit to the PR branch with
  `ADD_TO_PROJECT_PAT`: the pipeline runs once more (same version fingerprint - the database is reused) and merges.
  These files are never committed by hand.
- **Release**: 9.1 exports the tested application as the release zip; a release folder `repos/common/releases/<N>-*/`
  holds only its README (the release notes).
- **Resume at the failed step (I-078):** after job 5's checkpoint (5.2c, deploy=loaded) and job 6's (6.5a,
  deploy=upgraded), a job that fails keeps the steps that passed ("step:<name>" for this version). The next run with
  only a pipeline fix resumes at the failed step (`RESUME_AT`, db/decide.py); a change to the app, DB scripts or test
  data changes the fingerprint and runs the job in full. `/pipeline start-from 5.5` (or `Pipeline-Start-From: 6.8`)
  asks for a step; it is followed only when the steps before it passed for this version.
- **What runs (I-085):** the database jobs (2-8) run only when the PR changes the COMMON application (`repos/common/`
  apart from `deployment/`, `releases/`, `docs/` and the generated dependency map `db/deploy/dependencies.json` /
  `DEPENDENCIES.md` that step 9.2a adds). A PR that changes only workflows, actions, these scripts, release
  notes or docs runs job 1 (lint,
  security scan, self-test, dry run - no database) and job 9. A pipeline mistake that only shows on the real database
  surfaces in the next application release's run.
- **Pipeline changes** (workflows, actions, these scripts): `main` takes pull requests only, so step 1.1 (actionlint on
  every workflow, shellcheck, Python compile, self-test, dry run) checks them in their PR.
- **Workflow files (I-084, `WORKFLOWS-PLAN.md`)**: `pipeline.yml` (every app; the app is the PR title's `<APP>` or the
  full run's input `app`; KYC gets the offline checks 1.7-1.10 and the deploy check K (settings `repos/kyc/deployment/app.env`, I-096)),
  `control.yml` (supersede, `/pipeline start-from N`), `after-merge.yml` (private: records the merge, publishes nothing - I-091), `issues.yml` (disabled since I-091: no board, no weekly summary - kept as a placeholder; was: board, weekly summary), `maintenance.yml` (by hand: clean-up of
  runs, training videos); shared actions `setup-sqlcl` and `job-logs`. Copies of the files before I-084:
  `workflows-backup/2026-11-23/`.

**Faster re-pushes (agreed 3 Nov 2026):**
- **All test failures at once (A):** jobs 7 and 8 run every test step even after one fails (`KEEP_GOING`), and ZAP still
  runs; the job fails at the end and job 10 reports every failed step in one PR comment.
- **Skip the deploy when nothing to deploy changed (B):** job 1 fingerprints the built application and database
  scripts; 6.8 records the fingerprint of a version that passed its fresh install and upgrade test (`db/deployed.sql`,
  table `XXCI_DEPLOYED` of the pipeline user). When the database already holds this fingerprint (a push that changes
  only tests, docs or the pipeline), 3.2a says so and jobs 5-6 are skipped - job 7 tests straight away.
- **DB tests on the fresh install (C) - held back:** the DB tests still need data an upgraded database has (11 fail on
  a fresh install, run 41664366800); they run in job 7 only until the tests stand on their own fixtures.
- **The database is reinstalled only when its scripts change:** 5.6 / 6.10 record two fingerprints of the deployed
  version - the whole version and its database scripts alone (`XXCI_DEPLOYED`). 3.2a compares: the same version skips
  jobs 5-6 (B); the same database scripts make job 5 replace **only the APEX application** (5.1 remove the
  application, 5.2 import it - the schema, its objects and data stay; no backup schema) and skip job 6; other database
  scripts get the full fresh install (and the upgrade test when they differ from the base, F).
- **App parameter (I-106):** the application is one parameter - `COMMON` or `KYC`, from the PR title (or the full run's
  input). Job 1 sets `app_dir` (`repos/<app>`), reads `repos/<app>/deployment/app.env`, builds KYC (after COMMON) and
  sets `db` (jobs 2-8 run) for a KYC PR that changes `repos/kyc` code (not its releases, docs or deployment files).
  Jobs 3-9 get it as `APP_DIR`; `db/run.sh`, `checks/fingerprint.py` and the artifact paths follow it. COMMON behaves as
  before. KYC's own affected-tests rule is not done yet (all DB tests and pages run). The version record is one per
  application: COMMON keeps `xxci_deployed`, `xxci_passed` ...; another application's tables are `xxci_<app>_deployed`,
  `xxci_<app>_passed` ... (`db/deployed.sql` is given the prefix `t` and the app code; `XT` in `db/run.sh`). KYC needs its test users
  (`UI_USERS` in its `app.env`); job K (KYC deploy check, I-096) is gone - jobs 2-8 deploy and test KYC, step 3.5 registers it in COMMON.
- **Docs after the merge (E):** 9.1 exports only the release zip; the PR is merged and released, then 9.3 (readable
  export, SchemaSpy) are made (in their own folder, `$RUNNER_TEMP/docs`), kept as the artifact `common-docs` (9.3) and
  then added to the draft release (9.3c) - a docs problem is a warning, not a failure, and a release that cannot take the
  files leaves them in the artifact (#213, #214).
- **No upgrade test without database changes (F) - held back:** job 1 still compares the database scripts with the
  base, but job 6 runs after every full reinstall: job 7's DB tests need the data it restores (as C above).
- **Browser test beside the DB tests (G):** jobs 7 and 8 run at the same time - "7 DB tests and security" (7.2, 7.4,
  7.5) and "8 Browser test and ZAP" (8.0-8.4); the browser job never signs in as the pipeline user.
- **A PR tests what it changes; the full run tests everything (K, L):** job 1 (`checks/affected.py`) lists what the PR
  affects - the DB tests of its features, its changed tests and the release tests that name an object it changes; its
  pages plus the home page. Steps 5.6 / 7.2 run only those DB tests (the fixtures in `tests/setup` always), 8.3 opens
  only those pages, and ZAP is left out. A change to the framework, the shared components, the fixtures, the build or
  the pipeline tests everything. The **full run** is on demand only (Actions > COMMON > Run workflow): it tests all of
  `main` - every DB test, every page, ZAP - and a failure there becomes a COMMON issue (one per failing step; a repeat
  is a comment on it).
- **One SQLcl session for the DB tests (I):** consecutive test files of one schema run in one SQLcl session, reset
  between files (rollback, no APEX session, `dbms_session.reset_package`); a file that ends with `exit` runs alone.
- **Caches (D):** PMD (job 1) and Playwright's Chromium (job 8) are cached between runs.

**Quick fixes (agreed 3 Nov 2026 - one small fix should not cost a full run to find out it fails):**
- **The deploy decision (3.2a, `db/decide.py`)** compares this version (job 1, `checks/fingerprint.py`) with what the
  database holds (`db/deployed.sql`: `XXCI_DEPLOYED`, `XXCI_DEPLOYED_CODE`). Four fingerprints: the whole version, the
  database scripts, the **structure** (every install / upgrade step that is not a code object), the application without
  its supporting objects; plus a **code manifest** - one hash per package spec / body, view and trigger, keyed by its
  name without the file number (adding a file renumbers the later ones and changes neither). reuse and app need a
  version that passed the full install and upgrade test (`VERIFIED = FULL`).
- **Q1 quick check (deploy = patch):** same structure, only code objects changed (none removed or renamed). Job 5 Quick
  check runs just the changed files in one session (each holds one CREATE OR REPLACE, the same in install and upgrade),
  imports the app only when it changed, validates, and runs the tests of the changed objects and of every object that
  calls them (the live `USER_DEPENDENCIES`, `checks/affected.py --objects`). A failure is reported in minutes. A pass
  is followed by the full fresh install, upgrade test and job 7 in the same run - the rule "every release: fresh
  install and upgrade" stays; a quick check never merges. Any structure change, removed code object or unfinished
  deploy means the full deploy.
- **Q2 tests of what changed since the last tested commit:** on reuse / app, 7.1 runs only the tests affected by the
  changes since the head commit job 7 last tested (`TESTED_HEAD`), plus the files that failed or never ran then
  (`XXCI_FAILED_TESTS`); everything else passed against the same code. The quick check records only its failed files,
  never "tested". A full deploy runs the PR's tests (job 1).
- **Q3 / Q4 no repeated scans:** on reuse, APEX-SERT, DBSAT and the browser test are not run again when they passed for
  this version (and, for the browser, these pages) on an earlier run (`XXCI_PASSED`).
- **Q5** a page under `app/pages` tests that page only; the rest of `app/` (shared components, definition) tests everything.
- **The record never claims what the database may not hold:** a deploy marks it first (DIRTY / app or code objects
  unknown) and records the version only when it passed - a deploy cut short (failure, time limit, cancel) means the
  full deploy next time.
- **Every test file must run:** 7.2 / 4.Q7 compare the files expected with the files that ran; one that never ran (a
  session ended early) fails the step and runs again next time.
- **A newer push replaces the older run (`control.yml`, job 1)** - only while the old run is in jobs 1, 2, 7 or 8;
  during jobs 3, 4, 5, 6 or 9 (database changes, merge) it finishes and the new push waits. A queued run is replaced by GitHub.
- **Dry run (1.1, `checks/dryrun.sh`):** every path of `db/run.sh` (setup decisions, quick check, fresh, app only,
  upgrade, tests, a session ended early, reuse skips, browser, export) runs against a SQLcl stand-in
  (`checks/sqlcl-stub.sh`) on a built copy - a broken path fails before any run on GitHub.

**Hardening (review of 3 Nov 2026):**
- **H1** the test users get a random password in every run (8.2, masked; `db/test-passwords.sql`) - the fixed one in
  `db/admin/test-users.sql` never stays on the internet-facing validation app. For live tests by a person, run
  `db/admin/test-users.sql` again (it sets the fixed password).
- **H2** the database secrets are given only to the steps that sign in, never to third-party actions (ZAP, caches,
  uploads). **H3** every action of every workflow is pinned to a commit. **M6** the Python tools are installed with
  `--require-hashes` (`requirements-lint.txt`, `requirements-ui.txt` - keep Playwright's version equal to
  `PLAYWRIGHT_VERSION` in `tools.env`).
- **H4 test data in git, not in the database (agreed 3 Nov 2026):** `repos/common/db/admin/test-data.json` holds rows
  for every table (keys 900001+, codes `TD_`, test application `TDAPP`; `no_data` lists a table without rows and why).
  `db/load_data.py` + `db/load-data.sql` merge it on the primary key (insert when missing, update when there; triggers
  and row policies off during the load, WHO columns filled). It is loaded after the fresh install (5.2b), into the last
  release (6.3 - that release's own copy from git, so data and structure always match; while the last release has no
  file yet, this version's file loads tolerantly) and again after the upgrade (6.7). Nothing is kept between runs: the
  kept baseline schema of run 35 is dropped (3.3). A release that adds a table or a required column adds its rows in
  the same PR - 1.6a (`checks/test_data.py`) checks every row offline against the install's own definitions (CREATE
  TABLE and every later column / constraint change): the table and columns exist, NOT NULL, CHECK constraints, primary
  / unique keys and foreign keys (the parent row earlier in the file or seeded) - a bad row fails job 1, not job 4.
  One row per component (its main table); every other table is in "no_data". A change of the test data alone keeps
  the install fingerprint: after a failed 5.2b, the next run decides deploy=data (5.0a install guard, 5.2b, 5.3-5.5 -
  no redeploy).
- **Draft PR vs Ready for review (I-075, I-094):** a draft PR runs nothing - every job is skipped, so work can be
  pushed to a draft as often as needed. Marking the PR Ready for review (and every push after it, and the full run)
  runs the full validation (jobs 1-9 with APEX-SERT, DBSAT and ZAP), which merges when it passes. APEX-SERT is
  installed once and never removed.
- **Test data only in dev (I-076):** the test-data steps (5.2b, 6.3, 6.7) refuse to run unless `DB_TARGET=dev` (set by
  the workflow for the Oracle_Dev_DB jobs) - a deployment to test or later never loads test data.
- **Resume inside job 5 (deploy=loaded):** 5.2c records this version installed with its test data; when job 5 then
  stops later (5.3-5.5) and the fix changes only the pipeline's own files, the next run resumes at 5.3 (5.0a loaded
  guard) - no remove, no redeploy, no data reload. Any change to the DB scripts, app or test data deploys in full.
- **Upgrade = fresh (6.8):** 5.5 keeps the fresh install's structure (tables, columns, keys and their state, indexes,
  code objects; `XXCI_FRESH_SCHEMA`); after the upgrade and the delta load the upgraded database must show exactly
  the same lines (row counts are shown for information).
- **Restart points (agreed 3 Nov 2026):** a job is the smallest restart point; jobs 1 and 3 always run.
  - *Upgrade only:* job 5 that passed for this exact version is recorded (`XXCI_PASSED` `fresh`); when the run did not
    finish (e.g. job 6 failed, then a pipeline-only fix), job 3 decides `upgrade`: job 5 is skipped, job 6 runs.
  - *Asked for:* `Pipeline-Start-From: N` in the pushed commit's message (Claude, with a fix), `/pipeline start-from N`
    in a PR comment by the owner (`control.yml` job 2: label `start-from-N` + re-run; job 9 removes the label), or
    the full run's "Start from" input. N = 4 (fresh install and upgrade test again), 5 (skip job 5 when it passed for
    this version), 6 (skip jobs 5-6 when the database holds this version fully verified). It is never later than the
    records allow - job 3 says why (`start-note`) and starts earlier.
  - *Version guard:* jobs 4 (app only, quick check), 5 (upgrade), 6 and 7 first check that the database still holds
    what job 3 found; after another run changed it, the job stops ("re-run all jobs") instead of testing the wrong
    version.
  - *Job 10 says what next:* a temporary failure (connection, time-out) - re-run the failed jobs; otherwise push a fix,
    with the start point to name.
- **M2** job 3 makes one deploy decision (`deploy`: reuse / app / patch / full) that every later job reads. **M3** artifact
  names follow the job numbers. **M4** one pipeline comment per PR, updated by every run. **M5** artifacts are kept 7
  (logs), 14 (reports) or 30 days (release zip, docs); the browser test's **video and trace only in the full run and
  only when asked for** ("record video"). **L2** job 3 fetches only the merge commit and its base. **L3** a run that
  does not pass removes its draft release. **L4** the DB-test summary lists up to 200 lines. A self-test of the test
  selection (`checks/selftest.py`) runs in step 1.1.
- Not changed: M1 (lock only the database jobs - GitHub cannot hold one lock across several jobs, so another run could
  change the database between them), L1 (job 2 stays, for the agreed numbering), L5 (latency: needs the runner in
  OCI, J). **M7:** `main` has no enforced protection on a private Free repository - a person can still merge a red
  PR by hand; only the pipeline's own merge (9.2) checks the run.

**Runner image:** every workflow runs on `ubuntu-24.04` (pinned, not `ubuntu-latest`, which GitHub moves to Ubuntu 26
from 19 Oct 2026): the tools (SQLcl, Playwright, Instant Client) are set up on that image. Moving to a newer image is
a one-line change per workflow, made on purpose and tested by a run.

## Files
| File | Purpose |
|---|---|
| `app.env` | the application: id, schema, snapshot schema, workspace, pipeline user, tables never compared, URL path, browser-test users |
| `tools.env` | pinned tools with their SHA-256: gitleaks, SchemaSpy, Oracle JDBC, Instant Client (DBSAT), Playwright, APEX-SERT commit |
| `lib/fetch.sh`, `lib/app-url.sh` | checksum-verified download; the APEX URL read from the wallet (or `VAL_APP_URL`) |
| `ui/smoke_ui.py` | browser smoke test (8.3) |
| `db/dependencies.sql`, `db/compare_dependencies.py` | dependency check (5.4) |
| `db/sert-eval.sql` | APEX-SERT evaluation (7.4). APEX-SERT ships rule sets for 24.1, 24.2 and 25.1; for a newer APEX (26.1) it carries the newest rule set forward with SERT's own `RULES_PKG.UPGRADE_RULES` (a notice says so; when that is not possible the step is a notice, not a failure) |
| `lib/sql.sh` | SQLcl login to the validation ADB: wallet; connect line on stdin (never on the command line or in a file) |
| `release/carry.sh`, `checks/source_map.py` | 9.2a: the PR carries its generated files; SOURCE-MAP in step |
| `release/merge.sh`, `release/publish.sh` | 9.2 merge of the green PR (auto-merge); `publish.sh` is not called since I-091 (the release stays a draft) |
| `checks/report.py`, `checks/issues.py` | the PR comment's report; issues for the existing findings |
| `lib/step.sh` | step logging, step summary, failure record for job 10 |
| `db/bootstrap.sql` | users, pipeline user and its privileges, workspace, App Builder user, REST-enabled schemas (ADMIN) |
| `db/ci-password.sql` | new random password of the pipeline user for each job (ADMIN) |
| `db/needs-bootstrap.sql` | is the environment complete? (pipeline user, read only) |
| `db/backup-schema.sql` | 3.3: drops the backup schemas earlier pipelines made (refuses any name not ending in `_BKP`) |
| `db/snapshot.sql`, `db/snapshot_compare.py`, `db/keys-checked.sql` | upgrade test: the snapshot before the upgrade (6.4) and the nothing-lost and key checks after it (6.6) |
| `db/load_data.py`, `db/load-data.sql`, `../db/admin/test-data.json` | the test data: merged into the database in 5.2b, 6.3, 6.7 |
| `db/schema-summary.sql` | the structure lines of 5.5 / 6.8 (upgrade = fresh) |
| `checks/test_data.py` | 1.6a: every test row fits the install - columns, NOT NULL, checks, keys, foreign keys |
| `../../../.github/workflows/control.yml` | a newer push replaces the older run; `/pipeline start-from N` on a PR |
| `db/remove-app.sql`, `db/remove-objects.sql`, `db/app_objects.py` | remove the application and only its own database objects - never the schema or another application's objects (I-077) |
| `db/validate-online.sql` | no invalid object / compile error; application installed, available, every page present |

## Users on the validation database
- **Pipeline user `XXCI_DEPLOY`** (no stored password: every database job gives it a new random password as ADMIN,
  masked in the logs - `db/ci-password.sql`): create session / create table (with admin option, for
  the backup schema), create / alter / drop user (backup schema), `APEX_ADMINISTRATOR_ROLE` (remove / export the app);
  connects through XXFUSION and XXCUS as a proxy (`XXCI_DEPLOY[XXFUSION]`).
- **ADMIN** (secret `VAL_DB_ADMIN_PASSWORD`) only for the pipeline user's password at the start of each database job,
  3.2 bootstrap and 8.1 test users (creating APEX accounts outside
  an APEX session needs APEX instance rights for the session user).

Secrets (environment "Oracle DB Dev"): `VAL_DB_WALLET`, `VAL_DB_SERVICE`, `VAL_DB_ADMIN_PASSWORD`,
`VAL_DB_PASSWORD` (App Builder user XXCUS). Passwords must not contain a double quote.

## Reports (artifacts of each run)
| Artifact | Contents |
|---|---|
| `report-5-dependencies` | live dependencies (CSV) and `dependency-check.md` |
| `report-7-test` | `apex-sert-findings.csv` + summary; `dbsat/` (when set up) |
| `report-8-browser` | `ui/<user>/` video, screenshots of every page, `trace.zip` (open with `playwright show-trace`), `results.json` |
| `report-8-zap` | OWASP ZAP baseline report (HTML, JSON, Markdown) |
| `common-docs` | `COMMON-apex-docs.zip` (readable YAML of every page) and `COMMON-db-docs.zip` (SchemaSpy HTML) |
| `common-release-zip` | the importable APEXlang zip of the tested application |

## Releases
Job 9.1 builds the zip from the application that passed jobs 5-8 (SQLcl `apex export -exptype APEXLANG`) and puts it,
with the docs, into the draft GitHub Release `common-<N>` (N from the PR title; notes: the title and the linked
issues, plus `repos/common/releases/<N>-*/README.md` when the PR has one). Job 9.2 turns on auto-merge (GitHub merges once "9 Finalize
the PR" has passed); the release stays a draft: `after-merge.yml` publishes nothing (I-091) - a release is published by hand when wanted.

## Run locally
Set `SQL`, `WALLET`, `VAL_DB_SERVICE`, `ADMIN_PW` (and `XXCUS_PW` for setup, `PMD` for 1.6), then
`bash checks/run.sh`, `bash db/run.sh setup`, `bash db/run.sh fresh`, `bash db/run.sh upgrade origin/main`,
`bash db/run.sh test`.
