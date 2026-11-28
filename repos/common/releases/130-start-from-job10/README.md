# COMMON 130 - job 10 sets the start point

On top of COMMON 129. Pipeline only; no table, package, page or seed change.

| Issue | Change |
|---|---|
| I-105 (#287) | When a run fails in job 4, 5, 6, 7 or 8 and the error is not temporary, job 10 sets the label `start-from-N` on the PR (N = 5, 6 or 7 for the failed job) and says so in its PR comment. The next push resumes at that job; job 3 follows the label only when its records allow, and job 9 clears it after one run. `/pipeline start-from N` (or `auto` to start from job 1) stays as a manual override. |
| - | `CLAUDE.md`: working rule - answers short, plain, to the point. |

Checked offline: actionlint, the job 10 script parses. The first real run is the next failing PR run; if no `start-from-N` label appears on the PR after a failure in jobs 4-8, #287 is reopened.
