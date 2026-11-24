# COMMON 121 - After merge: no public output

On top of COMMON 120. A pipeline-only release: no application or database change.

| Issue | Change |
|---|---|
| I-091 (#262) | `after-merge.yml` publishes nothing: no GitHub Release, no project README sync, no MkDocs site on GitHub Pages, no issue or PR comment. It only records the merge in the run summary. |
| I-091 (#262) | The pipeline's draft release (step 9.1a, the tested zip) stays a draft - visible only to the repository's collaborators; it is published by hand when wanted. |
| I-091 (#262) | `issues.yml` is disabled (runs by hand only and does nothing): no issue goes on a GitHub Project board by itself, and no weekly backlog summary. |

**By the user:** new issues are put on their board by hand; GitHub Pages still serves the site already on `gh-pages` - turn it off in Settings > Pages (`GITHUB-SETUP.md` step 8).

Checked offline: actionlint, zizmor, the pipeline lint.
