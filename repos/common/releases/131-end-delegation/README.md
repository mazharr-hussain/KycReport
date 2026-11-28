# COMMON 131 - cancel a delegation that starts today

On top of COMMON 130. Changes one package routine; no table, page or seed change. This release's database change makes the
pipeline run its full validation (fresh install, upgrade test, DB tests, APEX-SERT, DBSAT, browser test, ZAP, docs).

| Issue | Change |
|---|---|
| I-103 (#281) | `XXFND_WORKFLOW_PKG.END_DELEGATION`: a delegation that has not started, or starts today, and is ended today or before (the default) is removed; before, it stayed active until midnight and no routine could cancel a delegation made by mistake. A later end date only shortens it; a delegation that started earlier ends on the given day, as before. |

## Tests
`tests/r123_common_test.sql`: ending a delegation that starts today removes it; one that has not started is removed; a future end date only shortens one that starts today (the old "ends it on the given day" check is kept).

## What this run also shows (not part of the change)
- APEX-SERT on APEX 26.1 (COMMON 128, #208): step 7.4 prints `SERT-NOTE ... carried forward` and the evaluation, or `SERT-SKIP` with the reason.
- The documentation artifact `common-docs` (COMMON 129, #213 / #214): step 9.3 and its artifact.
- `start-from-N` set by job 10 after a failure in jobs 4-8 (COMMON 130, #287), if a job fails.

## Test fix
`r82_workflow_test.sql`: removed the CASE_RFI check. CASE_RFI is a KYC approval type, so a COMMON test must not check it (the shared database can hold KYC).
