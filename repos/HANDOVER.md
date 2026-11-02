# Handover - current state for a new chat (as of 2 Nov 2026: COMMON 113 / KYC 105, COMMON CI/CD chain)

Read this first, then `ISSUES.md` (the issue backlog - keep it updated), then `CLAUDE.md` (rules) and the requirements in
git: `repos/common/docs/README.md` and `repos/kyc/docs/README.md` (one folder per component under `docs/components/`).

## 1. Working rules (from the user)
- Issues first, then a plan with pros and cons, then the user's approval - **never change, push or run anything before
  "yes"**. Answers short, few tokens. Every reported item becomes a GitHub issue (one label `COMMON` / `KYC`, its I-number
  in the title, body lines `Type: Bug|Enhancement|Task` and `Priority: P1|P2|P3`).
- Work only in `repos/common` (COMMON, app 135, schema XXFUSION) and `repos/kyc` (KYC, app 134, schema XXCUS); `apex/` is
  frozen; never run `repos/tools/build_repos.py`. Pushing and merging are allowed; never touch Netlify.
- One package per component; no HTML in PL/SQL; OOTB APEX (Redwood Light); COMMON data changes only through COMMON
  routines; COMMON is never duplicated; no install error ever (checked step scripts).
- Current focus: **COMMON only**. KYC, infra and IDCS wait until the user asks.

## 2. Use the skills (always, before reviewing or changing anything)
- **Oracle skills** - clone/update `mazharr-hussain/OracleskillsMirror` to `/home/user/mazharr-hussain/oracleskillsmirror`
  (fetch the latest first) and read the matching skill file before the work:
  - database objects, PL/SQL, SQL scripts: `db/SKILL.md`
  - APEX / APEXlang (APEX 26.1): `apex/apexlang/26.1/` (generation, validation, `apexlang-deploy` - SQLcl `apex validate`
    then `apex import` in the same session)
  - OCI: `oci/SKILL.md` (OKE only today; no compartment / vault skill - Terraform patterns from oracle-devrel repos)
- **Claude Code skills** of this session where they fit (e.g. `code-review`, `security-review`, `simplify` on a diff).
- Validate offline with the skills (APEXlang validation, SQLcl 26.1.2 - `sqlcl-latest` applies newer APEX rules); the
  database checks run in the GitHub pipeline (section 3), not in the chat session.

## 3. COMMON CI/CD chain (`repos/common/deployment`, workflows `pipeline.yml` + `common-pipeline.yml`)
- A PR that changes `repos/common/**` starts **one record** in Actions: `<PR title>:<run number>`. PR title convention:
  `<APP> <release>: <description>` (e.g. `KYC 102: Party Type LOV on Create Request`). Inside: one Child job
  `<PR title> - Child pipeline:<n>` - steps in sequence share one job; separate jobs only for parallel work.
- Steps: **offline** `checks/run.sh` (static `pr_checks.py`, requirements docs check (warning), build, APEXlang validate;
  PMD warnings) -> **database** `db/run.sh <base>` only when offline passed (bootstrap, uninstall app 135 + XXFUSION
  objects, deploy this version, uninstall, deploy the last version, upgrade to this version, re-run, invalid objects,
  test users, tests).
- **Failure**: a comment on the open PR (step, errors, log tail, run link) - the PR stays open, a pushed fix restarts the
  chain; an issue (label COMMON) only when there is no PR. **All green**: the PR is merged into main and, when the PR adds
  `repos/common/releases/*_N.zip`, GitHub Release `COMMON N` with that zip (manual deployment download).
- Claude does **not** watch runs - GitHub reports. Merges made by the pipeline do not start other workflows on main
  (e.g. `issues-sync`).
- Validation database: separate Always Free ADB (Jeddah), APEX 26.1.6, workspace XXCUS (schemas XXCUS + XXFUSION).
  Login: wallet + ADMIN, then `ADMIN[XXFUSION]` proxy (`lib/sql.sh`). Secrets in environment **Oracle DB Dev**:
  `VAL_DB_WALLET`, `VAL_DB_SERVICE`, `VAL_DB_ADMIN_PASSWORD`, `VAL_DB_PASSWORD` (App Builder user XXCUS).
- KYC still uses `checks.yml` / `docs-check.yml` (only for `repos/kyc/**`); its own pipeline comes later.

## 4. Open items
- PR #199 `COMMON 113: Pipeline wrapper - one record per run` - first green run not yet confirmed; merges itself when
  green. Open question: title `COMMON 114` or no release number for pipeline-only PRs.
- Issues #196 / #197 (COMMON install fixes, merged in #194) still open - close them.
- Later: Claude GitHub app fixes failures automatically (needs secret `CLAUDE_CODE_OAUTH_TOKEN`); KYC pipeline
  (`repos/kyc/deployment/`, same pattern).
- From the backlog (`ISSUES.md`): C18 KYC must call `APP_USER`; one approval process per component; L1 pipeline; stage
  gaps; screening questions; question display types; old KYC tests; C17 badge tones; COMMON-ISSUES C13-C16.

## 5. Parked (do not touch until the user asks)
- IDCS / OCI (#195, #198): GitHub OIDC token exchange works with a trust **without impersonation** - IDCS maps the token's
  `sub` to the service user `repo:mazharr-hussain/KycReport:environment:Oracle_OCI` (group `github-ci`, policy
  `manage all-resources in tenancy`); environment `Oracle_OCI` (secrets `OCI_OIDC_CLIENT`, `OCI_TENANCY`, variables
  `OCI_DOMAIN_URL`, `OCI_REGION`). Terraform templates in `repos/infra/` (compartment `Common`: plan OK, apply not run).
  Workflows `idcs-trust`, `val-oci-setup`, `connectivity`, `infra` - manual / parked.
- Retention two-stage review design - placeholder only.

## 6. How the latest COMMON pieces work (quick reference)
- **Build**: `sh repos/common/build.sh [--release N]` -> `dist/app` + zip; new pages need a `SOURCE-MAP.json` entry.
- **DB scripts**: `db/manifest.json` (install / upgrade sequence, units); base table scripts create only when missing;
  every change is a checked step (`XXFND_DDL_PKG`). Each release: `repos/<app>/releases/NNN-name/` (README,
  `run-release.sql`, db + app files) and the zip.
- **API call** = Remote Server + Web Credential + REST Source Catalog service (`XXFND_INTEGRATION_PKG.CALL`).
- **Server** (`XXFND_SERVERS`): `SERVER_CODE` + `REMOTE_SERVER_CODE`; name / URL read live in `XXFND_SERVERS_V`.
- **Menu**: folders link to COMMON page 100 (`P100_GROUP`).
- **Approval**: process = approval type; rules -> levels; approver ROLE / USER / GROUP / REQUESTER (`GROUP_USERS`).
