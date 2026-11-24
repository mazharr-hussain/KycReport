# COMMON 119 - Fixed issues close when the pipeline merges; page 169 loads fast

On top of COMMON 121. Pipeline changes, one build change and the database / page changes behind page 169.

| Issue | Change |
|---|---|
| I-089 (#258) | Page 169 (All Pages) timed out in the browser test: its view `XXFND_PAGE_CATALOGUE_V` ran two sub-queries per page row, each scanning five APEX dictionary views (`XXFND_PAGE_LINKS_V`). The view now reads the links once per query (`MATERIALIZE`) and joins them to the pages with one `GROUP BY`; menus and opens are summed the same way. Same columns and values. |
| I-089 (#258) | `XXFND_PAGE_LINKS_V` reads the APEX dictionary views for the applications registered in `XXFND_APPLICATIONS` only, not every application of the instance; the page 169 report loads lazily (`lazyLoading`), so the page opens at once and the report fills in. |
| I-089 (#258) | `build.py` writes `db/deploy/dependencies.json` with sorted keys: it was in file-system order, which differs per runner, so step 9.2a committed a "new" map on every run and a PR could loop without merging. |
| I-087 (#255) | GitHub does not close a PR's "Fixes #n" issues when the pipeline's token merges it. Step 9.2b now turns auto-merge on with a person's token (`PIPELINE_MERGE_TOKEN`, else `ADD_TO_PROJECT_PAT`), so the merge is the owner's and GitHub closes the issues itself - no workflow touches issues (after-merge publishes nothing since I-091). If GitHub refuses that token, the workflow token turns auto-merge on and the issues are closed by hand. The issues left open by Releases 117, 118 and 121 were closed by hand. |

Checked offline: actionlint, zizmor, `bash -n`, the dry run, the APEXlang `lazyLoading` attribute (APEX skill, 26.1 inventory); the view reviewed column by column against the old one (Oracle DB skill: correlated sub-queries rewritten as joins, the expensive part materialized once) and the COMMON build.
