# COMMON 119 - Fixed issues close when the pipeline merges; page 169 loads fast

On top of COMMON 118. One pipeline change and one database change (the view behind page 169).

| Issue | Change |
|---|---|
| I-089 (#258) | Page 169 (All Pages) timed out in the browser test: its view `XXFND_PAGE_CATALOGUE_V` ran two sub-queries per page row, each scanning five APEX dictionary views (`XXFND_PAGE_LINKS_V`). The view now reads the links once per query (`MATERIALIZE`) and joins them to the pages with one `GROUP BY`; menus and opens are summed the same way. Same columns and values. |
| I-087 (#255) | GitHub does not close a PR's "Fixes #n" issues when the pipeline's token merges it. `after-merge.yml` (job 2) now closes them, as completed, with a comment naming the PR. The issues left open by Releases 117 and 118 were closed by hand. |

Checked offline: actionlint, zizmor, the issue-number extraction on a sample PR body; the view reviewed column by column against the old one (Oracle DB skill: correlated sub-queries rewritten as joins, the expensive part materialized once) and the COMMON build.
