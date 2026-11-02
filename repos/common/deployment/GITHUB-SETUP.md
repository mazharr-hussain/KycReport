# GitHub setup for the COMMON pipeline - steps for later (user)

The pipeline (`.github/workflows/pipeline.yml`) and its scripts are in `main` and run on every pull request. These
GitHub settings are still to be done by the user; until then the pipeline runs and reports, but a green run does not
merge the PR by itself (merge it by hand).

| # | Where (github.com, repository KycReport) | Step | Why |
|---|---|---|---|
| 1 | Settings > General > Pull Requests | Tick **Allow auto-merge** | Step 9.2: GitHub merges the PR when the pipeline is green |
| 2 | Settings > Rules > Rulesets > New branch ruleset, target `main` | Enable **Require status checks to pass**, add the check **`9 Finalize the PR`**; enable **Require a pull request before merging** | Nothing reaches `main` without a green pipeline; job 9 fails whenever an earlier job failed |
| 3 | Settings > Environments > **Oracle DB Dev** | Keep the secrets `VAL_DB_WALLET`, `VAL_DB_SERVICE`, `VAL_DB_ADMIN_PASSWORD`, `VAL_DB_PASSWORD` (no other secret is needed - the pipeline user `XXCI_DEPLOY` gets a new random password in every job) | Jobs 5-9 sign in to the validation database |
| 4 | Netlify (app.netlify.com) and Settings > GitHub Apps | Unlink / delete the Netlify site and remove the Netlify app from the repository; then tell Claude to delete `netlify.toml` (issue #203) | Netlify is removed; `netlify.toml` keeps builds skipped until the site is unlinked |
| 5 | Pull request #199 | Close it (replaced by #204) | Old pipeline wrapper PR |

## Who does what (agreed with the user)
- **Claude**: changes the code and reviews it (offline: Oracle skills, APEXlang validation, lint), opens the PR and
  pushes. Nothing else.
- **The git workflow (pipeline)**: everything after the push - offline validation, database setup, fresh install,
  upgrade with data, online validation, tests, release zip, merge (GitHub auto-merge on the required check) and the
  error report on the PR.
