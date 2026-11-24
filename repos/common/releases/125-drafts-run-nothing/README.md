# COMMON 125 - A draft PR runs nothing

A pipeline-only release (`pipeline.yml`): no application or database change. Replaces COMMON 124's "a draft runs job 1".

| Issue | Change |
|---|---|
| I-094 (#268) | On a draft PR every job is skipped, job 9 included: a draft can be pushed as often as needed at no cost. "Ready for review", every push after it and the full run on demand run the full validation and merge, as before. The draft step 9.2b ("not merged") is removed. |

A draft cannot be merged, and "Ready for review" starts a new run whose "9 Finalize the PR" check replaces the skipped one.

Checked offline: actionlint, zizmor (same findings as main), the pipeline dry run.
