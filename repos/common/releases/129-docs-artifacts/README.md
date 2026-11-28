# COMMON 129 - database and APEX documentation reach the release

On top of COMMON 128. Pipeline only; no table, package, page or seed change.

| Issue | Change |
|---|---|
| I-057 (#213) | SchemaSpy HTML documentation of the tested XXFUSION schema (step 9.3b) was made in every full run but never kept: the zip / upload step after it failed with "no matches found for COMMON-apex-docs.zip" (COMMON 126's run), so no artifact and nothing on the release. The step now writes both zips to its own folder (`$RUNNER_TEMP/docs`), checks that they exist, and the artifact `common-docs` is uploaded first. |
| I-058 (#214) | The same for the readable APEX documentation (SQLcl `apex export -exptype READABLE_YAML -split`, step 9.3a): kept in the same artifact. |
| I-057, I-058 | The upload to the draft release is its own step (9.3c); when it fails, or the PR has no release, the documentation stays in the artifact. A documentation problem is still only a warning after the merge. |

Not changed: SchemaSpy spends about five minutes on its routine collection and ends with `ORA-64451` (no routine pages) - a SchemaSpy / database limit; the table, column, key and diagram pages are complete (121 tables in the COMMON 126 run).

Checked offline: actionlint, zizmor, the pipeline dry run. The first real run is this release's job 9.3 (a full run); if the artifact `common-docs` is missing, #213 and #214 are reopened.
