# COMMON 118 - Pipeline-only changes run job 1 only

On top of COMMON 117. A pipeline-only release: no application or database object of COMMON changes.

| Issue | Change |
|---|---|
| I-086 (#254) | `repos/ISSUES.md` frozen as history (the backlog is the GitHub issues); step 9.2a carries only the generated files. |
| I-085 (#252) | The database jobs (2-8) run only when the PR changes the COMMON application (`repos/common/` apart from `deployment/`, `releases/` and `docs/`). Workflow, action, pipeline-script, release-note and docs changes run job 1 (lint, security scan, self-test, dry run) and job 9, then merge. |

Checked offline: actionlint, and the scope rule tested on five kinds of change (a workflow only, a pipeline script only, the
application, the application and a workflow, KYC only).
