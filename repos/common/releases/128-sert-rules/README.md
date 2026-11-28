# COMMON 128 - APEX-SERT runs on APEX 26.1

On top of COMMON 127. Pipeline only; no table, package, page or seed change.

| Issue | Change |
|---|---|
| I-052 (#208) | APEX-SERT's latest release (the pinned commit is upstream's HEAD) has SERT-SECURITY rule sets for APEX 24.1, 24.2 and 25.1 only. Its evaluation picks the rule set by the database's APEX version (26.1), so step 7.4 was skipped. Step 7.4 (`db/sert-eval.sql`) now finds the newest rule set SERT has and carries it forward to the database's APEX version with SERT's own `RULES_PKG.UPGRADE_RULES`, then evaluates. `db/run.sh` shows the `SERT-NOTE` that says so. If the carry-forward fails the step stays a `SERT-SKIP` notice, never a failure. |

Checked offline: shellcheck, the pipeline dry run. The first real evaluation is this release's job 7.4; if no SERT results show there, #208 is reopened.
