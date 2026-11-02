# GitHub setup for the COMMON pipeline - steps for later (user)

The pipeline (`.github/workflows/pipeline.yml`) and its scripts are in `main` and run on every pull request. These
GitHub settings are still to be done by the user; until then the pipeline runs and reports, but a green run does not
merge the PR by itself (merge it by hand).

| # | Where (github.com, repository KycReport) | Step | Why |
|---|---|---|---|
| 1 | Settings > General > Pull Requests | Tick **Allow auto-merge** | Step 9.2: GitHub merges the PR when the pipeline is green |
| 2 | Settings > Rules > Rulesets > New branch ruleset, target `main` | Enable **Require status checks to pass**, add the check **`9 Finalize the PR`**; enable **Require a pull request before merging** | Nothing reaches `main` without a green pipeline; job 9 fails whenever an earlier job failed |
| 3 | Settings > Environments > **Oracle DB Dev** | Keep the secrets `VAL_DB_WALLET`, `VAL_DB_SERVICE`, `VAL_DB_ADMIN_PASSWORD`, `VAL_DB_PASSWORD` (no other secret is needed - the pipeline user `XXCI_DEPLOY` gets a new random password in every job) | Jobs 5-9 sign in to the validation database |
| 4 | Netlify | Later, when the user wants Netlify again (not now): remove the `ignore` line from `netlify.toml` (issue #203) | Netlify stays connected; `netlify.toml` keeps every build skipped until then |
| 5 | Pull request #199 | Close it (replaced by #204) | Old pipeline wrapper PR |
| 6 (optional) | Settings > Secrets and variables > Actions > Variables | `DBSAT_ZIP_URL` and `DBSAT_ZIP_SHA256`: where the pipeline downloads DBSAT (Oracle download after accepting its licence, e.g. a private release asset) and its SHA-256 | Step 8.5 runs DBSAT; skipped with a notice until set (issue #209) |
| 7 (optional) | Settings > Secrets and variables > Actions > Variables | `VAL_APP_URL`: the validation APEX URL (`https://.../ords`) - only if the one read from the wallet is wrong | Browser tests (8.3) and ZAP (8.6) |

## Who does what (agreed with the user)
- **Claude**: changes the code and reviews it (offline: Oracle skills, APEXlang validation, lint), opens the PR and
  pushes. Nothing else.
- **The git workflow (pipeline)**: everything after the push - offline validation, database setup, fresh install,
  upgrade with data, online validation, tests, release zip, merge (GitHub auto-merge on the required check) and the
  error report on the PR.
