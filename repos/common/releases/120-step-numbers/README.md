# COMMON 120 - Pipeline step numbers: no repeats, run order, no gaps

On top of COMMON 118 (separate from 119). A pipeline-only release: step numbers only - no step added, removed or
reordered, no application or database change.

| Issue | Change |
|---|---|
| I-090 (#259) | Every step number is used once per run (alternative paths share one, only one of them runs), follows the run order, belongs to its own job and leaves no gap. The password step of each database job is N.0; upload and report-collection steps carry no number. |

Checked offline: the pipeline lint, self-test and dry run; the step logs of all 40 dry-run scenarios (no repeat, run
order, own job); the workflow step names.
