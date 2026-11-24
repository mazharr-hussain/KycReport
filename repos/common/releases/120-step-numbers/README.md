# COMMON 120 - Pipeline step numbers: no repeats, run order, no gaps

On top of COMMON 118 (separate from 119). A pipeline-only release: step numbers only - no step added, removed or
reordered, no application or database change.

| Issue | Change |
|---|---|
| I-090 (#259) | Cancel stops a run: jobs 5-8 and the ZAP step started with `always()`, which GitHub never cancels; they use `!cancelled()` now (same behaviour otherwise). Jobs 9 and 10 keep `always()` - they report. |
| I-090 (#259) | Every step number is used once per run (alternative paths share one, only one of them runs), follows the run order, belongs to its own job and leaves no gap. The password step of each database job is N.0; upload and report-collection steps carry no number. |
| I-090 (#259) | A pipeline-only PR runs job 1 only also after step 9.2a: the dependency map it adds (`db/deploy/dependencies.json`, `DEPENDENCIES.md`, generated) no longer counts as an application change, so the run after 9.2a does not deploy and test the app. |

Checked offline: the pipeline lint, self-test and dry run; the step logs of all 40 dry-run scenarios (no repeat, run
order, own job); the workflow step names.
