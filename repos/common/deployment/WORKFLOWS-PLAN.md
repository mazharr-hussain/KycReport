# Workflows plan - minimum files, reusable, controlled by parameters (I-084)

Status: **done on the branch (I-084, issue #250), not pushed.** Backup of the files before it:
`repos/common/deployment/workflows-backup/2026-11-23/` (15 workflows + the `setup-sqlcl` action).

## 1. Goal

- As few workflow files as possible: **15 -> 5**, plus 2 shared actions (one more than first planned: see section 9).
- One pipeline for every application (COMMON, KYC, later ones). The app is a **parameter**, never a copied file.
- Shared steps live once, in composite actions, and every job calls them.
- One route for each event: a merge is handled in one place, an issue in one place.
- Names stay the same where GitHub settings depend on them: the required check stays **"9 Finalize the PR"**.

## 2. The parameter: which application

| Where it comes from | Value |
|---|---|
| Pull request | the PR title: `COMMON Release N: ...` -> `COMMON`, `KYC Release N: ...` -> `KYC` |
| Full run (by hand) | input `app` (choice: COMMON / KYC) |
| Push to main (after a merge) | the merged PR's title (as `release.yml` reads it today) |

Each application has **one settings file**, `repos/<app>/deployment/app.env`. It holds the APEX application id,
the parsing schema, the workspace, the release tag prefix, the zip name, the browser-test users and the database
environment (`Oracle_Dev_DB`). The scripts in `repos/common/deployment/` are shared and read only these settings.
They take no app-specific code.

An app with no `app.env` yet (KYC today - COMMON is finished first) runs the offline checks only (job 1, what
`checks.yml` + `docs-check.yml` do today). Adding its `app.env` later switches its full pipeline on, with no new
workflow file.

## 3. The target files

| # | File | Starts on | Replaces | What it does |
|---|---|---|---|---|
| 1 | `.github/workflows/pipeline.yml` | pull request; PR comment; by hand | `pipeline.yml`, `supersede.yml`, `pipeline-command.yml`, `checks.yml`, `docs-check.yml` | Jobs 1-10 for the app of the PR. Job 0 "Control" handles a newer push replacing an older run (supersede) and the owner's `/pipeline start-from N` comment; it starts nothing else on a comment. |
| 2 | `.github/workflows/after-merge.yml` | push to main; by hand | `release.yml`, `generated-files.yml`, `docs-sync.yml`, `docs.yml`, `pipeline-check.yml` | One job per task, in order: publish the release, commit the generated files, sync the requirements to the Project README, publish the docs site, and lint a pipeline-only push. A task with nothing to do is skipped and says why. |
| 3 | `.github/workflows/issues.yml` | issue opened / labelled / closed; Mondays | `add-to-project.yml`, `issues-sync.yml`, `weekly-backlog.yml` | Puts the issue on its board with Type and Priority, writes its `ISSUES.md` row, and on Mondays refreshes the weekly backlog summary. Runs **once** per issue event (today: 3 runs). |
| 4 | `.github/workflows/maintenance.yml` | by hand only | `cleanup-runs.yml`, `training-videos.yml` | Input `task`: `cleanup-runs` (dry run first) or `training-videos`. |
| A | `.github/actions/setup-sqlcl/` | (called by jobs) | - | Kept as it is: Java, SQLcl, OCI sign-in, Vault, wallet. |
| B | `.github/actions/job-logs/` (new) | (called by jobs) | the repeated "Step logs" / report upload steps | Uploads a job's step logs and reports with the right job number. |

## 4. One route for a merge

- Job 9.2 only **turns on auto-merge**. GitHub merges as soon as "9 Finalize the PR" has passed (a job cannot merge
  while it is itself the required check). Auto-merge is switched on as the owner, so the merge starts
  `after-merge.yml`.
- `after-merge.yml` does all the work that follows a merge, once. The publish / regenerate code is removed from
  `release/merge.sh`.
- The docs site job (`mkdocs gh-deploy`) gets the git credentials it needs for that one step only. This fixes the
  break caused on 23 Nov by `persist-credentials: false`.

## 5. Also in this change

- Log and artifact names use the new job numbers (today the step-times table still says "4-fresh", "6-test").
- `repos/common/deployment/README.md`, `GITHUB-SETUP.md`, `HANDOVER.md` and `CLAUDE.md` describe the 4 files.
- `CLAUDE.md`: the rule "pipeline fixes go straight to main" no longer applies, because main accepts only PRs.

## 6. How it is checked before any push

- actionlint and shellcheck on every file, zizmor (security), the pipeline's dry run and self-test.
- A **logic walk-through** of each job: what it needs, what it gets from earlier jobs, and the merge rule. This is
  what the linters missed on 23 Nov (job 9 without the version fingerprint, the merge step).
- A table of every trigger, mapping the old file to the new file and job, so nothing is lost.

## 7. Delivery

- One issue, **I-084**, and one PR on top of Release 117, together with I-075 to I-077, which already change the same
  files. One push, one run: a full validation, because it changes the pipeline itself.
- No change to the GitHub settings: the required check keeps its name, and auto-merge stays on.
- If something goes wrong, every old file is in the backup folder and can be restored by copying it back.

## 8. Risks

| Risk | How it is covered |
|---|---|
| An event no longer handled (e.g. a comment trigger) | the trigger table in section 6, checked file by file |
| Issue workflow fires twice (opened + labelled) | one job guarded on the event type, as add-to-project does today |
| The PR's own run uses the new files before they are proven | the run is the proof; the backup restores the old files in one commit |

## 9. As built (differences from the plan)

- **5 files, not 4:** supersede and `/pipeline start-from` are in `control.yml`. Inside `pipeline.yml` they would wait in
  its one-run-at-a-time group (`validation-db`) behind the very run they must stop.
- **`app.env`** is the existing `repos/common/deployment/app.env` (also read by `db/run.sh`). Job 1 takes the release tag
  (`APP_CODE`) and zip name (`ZIP_NAME`) from it. KYC gets the database jobs when it has its own file and the scripts read
  it (later, when COMMON is finished).
- **Pipeline-only lint on `main`** (`pipeline-check.yml`) is dropped: `main` takes PRs only, and job 1.1 now lints every
  workflow file (any `.github/` change runs the full pipeline).
- **No push to `main` by a workflow:** the ruleset refused `regenerate.sh` and `issues-sync` (their pushes failed since the
  rule came - Issues sync hid it). The generated files now come in the release PR (step 9.2a).
- **A merge made by the workflow token** starts no workflow, so `after-merge.yml` also starts when a pipeline run
  completes. It waits for that PR's merge (up to 10 minutes) and acts only if `github-actions` merged it, so each merge
  is handled once.

| Old file | Trigger | New place |
|---|---|---|
| pipeline.yml | PR to main; by hand | pipeline.yml (input `app` added) |
| supersede.yml | PR push | control.yml job 1 |
| pipeline-command.yml | PR comment | control.yml job 2 |
| checks.yml | PR touching repos/kyc; by hand | pipeline.yml 1.7-1.9 (KYC); by hand with `app: KYC` |
| docs-check.yml | PR touching repos/kyc/features | pipeline.yml 1.10 |
| release.yml | push to main | after-merge.yml job 2 |
| generated-files.yml | push to main (repos/common); by hand | pipeline step 9.2a (in the PR - main takes PRs only) |
| docs-sync.yml | push to main (docs README); by hand | after-merge.yml job 4 |
| docs.yml | push to main; by hand | after-merge.yml job 5 (with push credentials for gh-pages) |
| pipeline-check.yml | push to main | dropped - pipeline 1.1 in the PR |
| add-to-project.yml | issue events | issues.yml job 1 |
| issues-sync.yml | issue opened / closed | dropped - ISSUES.md frozen as history, the backlog is GitHub (I-086) |
| weekly-backlog.yml | Mondays; by hand | issues.yml job 2 |
| cleanup-runs.yml, training-videos.yml | by hand | maintenance.yml (input `task`) |
