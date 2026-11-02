# COMMON deployment (app 135, schema XXFUSION)

Everything the COMMON pipeline (`.github/workflows/common-pipeline.yml`) runs lives here. One GitHub job, steps in order;
a failing step stops the run and the pipeline opens (or comments on) a GitHub issue labelled COMMON with the error,
the run link and the end of the step's log. No e-mail is sent by the pipeline.

| Folder | Entry point | What it does |
|---|---|---|
| `checks/` | `run.sh` | Stage 1, offline: static checks (`pr_checks.py`), build, APEXlang validation (SQLcl, no DB). PMD (`pmd-plsql.xml`) runs as a pipeline step, warnings only. |
| `db/` | `run.sh <base-ref>` | Stage 2, only when stage 1 passed: bootstrap, uninstall, deploy this version, uninstall, deploy the last released version, upgrade to this version, re-run, invalid objects, test users, DB tests. |
| `lib/` | - | `sql.sh` (SQLcl login to the validation ADB: wallet + ADMIN, ADMIN[XXFUSION] for the schema), `step.sh` (step logging / failure record). |

Validation database: environment "Oracle DB Dev" - `VAL_DB_WALLET`, `VAL_DB_SERVICE`, `VAL_DB_ADMIN_PASSWORD`,
`VAL_DB_PASSWORD` (App Builder user XXCUS). Run locally: set `SQL`, `WALLET`, `VAL_DB_SERVICE`, `ADMIN_PW`, `XXCUS_PW`,
then `bash checks/run.sh && bash db/run.sh origin/main`.
