# GitHub setup for the COMMON pipeline - steps for later (user)

The pipeline (`.github/workflows/pipeline.yml`) and its scripts are in `main` and run on every pull request. A green
run merges the PR by itself (job 7.2, `release/merge.sh`, with the workflow token - no GitHub auto-merge needed) and
publishes its release. The settings below are still to be done by the user.

| # | Where (github.com, repository KycReport) | Step | Why |
|---|---|---|---|
| 1 | Settings > Secrets and variables > Actions > Secrets | Keep **`ADD_TO_PROJECT_PAT`** (classic token, scopes `repo` + `project`) | add-to-project.yml; job 7.2 also creates the issues for the existing findings with it, so they go on the board (with the workflow token the issue is created but no workflow starts) |
| 1a (optional) | Settings > Secrets and variables > Actions > Secrets | **`PIPELINE_MERGE_TOKEN`**: a fine-grained token on this repository (Contents, Pull requests: read and write; Workflows: read and write) | Only to let job 7.2 merge a PR that changes workflow files - the workflow token cannot; without it such a PR is left open with a note, merge it by hand. A PR that should not be merged yet: add the label **hold** |
| 2 | Settings > Rules > Rulesets > New branch ruleset, target `main` | Enable **Require status checks to pass**, add the check **`7 Finalize the PR`**; enable **Require a pull request before merging** | Nothing reaches `main` without a green pipeline; job 7 fails whenever an earlier job failed |
| 3 | Settings > Environments > **Oracle DB Dev** | Keep the secrets `VAL_DB_WALLET`, `VAL_DB_SERVICE`, `VAL_DB_ADMIN_PASSWORD`, `VAL_DB_PASSWORD` (no other secret is needed - the pipeline user `XXCI_DEPLOY` gets a new random password in every job) | Jobs 3-7 sign in to the validation database |
| 4 | Netlify | Later, when the user wants Netlify again (not now): remove the `ignore` line from `netlify.toml` (issue #203) | Netlify stays connected; `netlify.toml` keeps every build skipped until then |
| 5 | Pull request #199 | Close it (replaced by #204) | Old pipeline wrapper PR |
| 6 (optional) | Settings > Secrets and variables > Actions > Variables | `DBSAT_ZIP_URL` and `DBSAT_ZIP_SHA256`: where the pipeline downloads DBSAT (Oracle download after accepting its licence, e.g. a private release asset) and its SHA-256 | Step 6.5 runs DBSAT; skipped with a notice until set (issue #209) |
| 7 (optional) | Settings > Secrets and variables > Actions > Variables | `VAL_APP_URL`: the validation APEX URL (`https://.../ords`) - only if the one read from the wallet is wrong | Browser tests (6.3) and ZAP (6.6) |

## Clean up the run history (issue #219)
Actions -> **Clean up workflow runs** -> **Run workflow**: choose the workflow (`pipeline.yml`, ... or `all`), the minimum
age in days (0 = any) and the result (all / failure / cancelled / success / skipped). Run it first with **Dry run**
ticked (the default) - the run's summary lists what would be deleted - then again without it to delete. Running runs
and the clean-up run itself are never deleted; deleted runs (logs and artifacts) cannot be restored.

## Who does what (agreed with the user)
- **Claude**: changes the code and reviews it (offline: Oracle skills, APEXlang validation, lint), opens the PR and
  pushes. Nothing else.
- **The git workflow (pipeline)**: everything after the push - offline validation, database setup, fresh install,
  upgrade with data, online validation, tests, release zip, merge and release (job 7.2), issues for the existing
  findings (future releases) and the report on the PR. A pipeline failure is never logged as an issue: it is in the PR
  comment, and Claude's next push fixes it from there.

## Full run (on demand)
Actions -> **COMMON** -> **Run workflow** tests all of `main` (every DB test, every page, ZAP). Options: **Record a
video** of the browser test (large; only when needed) and **Refresh baseline** (makes the upgrade test's fixed data
set again from the database's current data). A failure becomes a COMMON issue.

## Branch protection (M7)
A private repository on GitHub Free does not enforce rulesets or branch protection: a person can merge a PR whose
pipeline failed. Only the pipeline's own merge (job 7.2) checks the run. GitHub Pro / Team enforces the required check
"7 Finalize the PR".

