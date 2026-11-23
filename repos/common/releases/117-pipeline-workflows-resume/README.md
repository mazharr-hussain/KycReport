# COMMON 117 - Pipeline: fewer workflow files, no backup schema, resume at the failed step

On top of COMMON 116. A pipeline-only release: no application or database object of COMMON changes. Checked offline:
actionlint on every workflow, zizmor (no new finding), shellcheck, the pipeline's self-test (51 checks), the dry run
of every database-job path (65 checks), and a test of step 9.2a against a local copy of the repository.

## What changes
| Issue | Change |
|---|---|
| I-084 (#250) | 15 workflow files become 5 (`pipeline`, `control`, `after-merge`, `issues`, `maintenance`) plus the shared actions `setup-sqlcl` and `job-logs`. The application is a parameter (PR title or the full run's input); KYC gets its offline checks (1.7-1.10) in the same pipeline. Log names use the job numbers 1-10. Old files kept in `repos/common/deployment/workflows-backup/2026-11-23/`. Plan and trigger table: `repos/common/deployment/WORKFLOWS-PLAN.md`. |
| I-084 (#250) | Nothing is pushed to `main` by a workflow (the ruleset refused it): the generated files and `ISSUES.md` come in the release PR itself (step 9.2a, `release/carry.sh`), and the run after that commit reuses the database and merges. |
| I-075 (#241) | APEX-SERT (3.4 install, 7.4) and DBSAT (7.5), and ZAP (8.6), run only in the full validation: a PR marked Ready for review, or the full run. A draft PR gets the quick validation and is not merged. APEX-SERT is installed once and never removed. |
| I-076 (#242) | No backup schema: 6.4 keeps a snapshot of the application's tables (row counts, rows by key) in a file and the database; 6.6 compares with it. An application never released skips the upgrade test. Test data loads only into the dev database (`DB_TARGET=dev`). |
| I-077 (#243) | 5.1 / 6.1 remove the application and only its own database objects (from its DB scripts, plus the ones every deploy recorded) - never the schema, never another application's objects. |
| I-078 (#244) | A job 5 / 6 that fails after its checkpoint keeps the steps that passed; the next run with a pipeline-only fix resumes at the failed step. `/pipeline start-from` also takes a step (e.g. `5.5`). |

## Deploy
Nothing to install by hand. The PR runs the full pipeline (it changes the pipeline itself). Still to do later: the
pipeline user's CREATE / ALTER / DROP USER grant stays while 3.3b drops the old backup schemas once; it can be removed
in a later release.
