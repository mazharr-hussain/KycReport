# COMMON 124 - A draft PR runs job 1 only

A pipeline-only release (`pipeline.yml`): no application or database change.

| Issue | Change |
|---|---|
| I-093 (#266) | A push to a draft PR runs job 1 only (offline checks: lint, build, APEXlang validation, static checks, PMD) and job 9, which does not merge. Before, a draft ran the database jobs 3-8 too (all but APEX-SERT, DBSAT and ZAP), almost as long as the full run. Ready for review runs the full validation and merges, as before. |

Checked offline: actionlint, zizmor, the pipeline dry run.
