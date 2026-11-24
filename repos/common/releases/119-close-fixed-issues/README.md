# COMMON 119 - Fixed issues close when the pipeline merges

On top of COMMON 118. A pipeline-only release: no application or database object of COMMON changes.

| Issue | Change |
|---|---|
| I-087 (#255) | GitHub does not close a PR's "Fixes #n" issues when the pipeline's token merges it. `after-merge.yml` (job 2) now closes them, as completed, with a comment naming the PR. The issues left open by Releases 117 and 118 were closed by hand. |

Checked offline: actionlint, zizmor, and the issue-number extraction on a sample PR body.
