# COMMON 122 - Maintenance: clean-up dry run, private training videos

On top of COMMON 119. A pipeline-only release (`maintenance.yml`): no application or database change.

| Issue | Change |
|---|---|
| I-092 (#264) | Task `cleanup-runs`, dry run: the list of matching runs is cut to 200 before its columns are taken (`head -200 runs.tsv \| cut -f2-`), so the pipe no longer breaks (SIGPIPE, exit 141) when more than 200 runs match. |
| I-092 (#264) | Task `training-videos` packs the videos as a 30-day workflow artifact instead of publishing the GitHub Release `training-videos` - nothing public (I-091). |

Checked offline: actionlint, zizmor.
