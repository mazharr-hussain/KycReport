# Handover - current state for a new chat (as of 2 Nov 2026: COMMON 113 / KYC 105, COMMON CI/CD chain)

Read this first, then `ISSUES.md` (the issue backlog - keep it updated), then `CLAUDE.md` (rules) and the requirements in
git: `repos/common/docs/README.md` and `repos/kyc/docs/README.md` (one folder per component under `docs/components/`).

## 1. Working rules (from the user)
- Issues first, then a plan with pros and cons, then the user's approval - **never change, push or run anything before
  "yes"**. Answers short, few tokens. Every reported item becomes a GitHub issue (one label `COMMON` / `KYC`, its I-number
  in the title, body lines `Type: Bug|Enhancement|Task` and `Priority: P1|P2|P3`).
- Work only in `repos/common` (COMMON, app 135, schema XXFUSION) and `repos/kyc` (KYC, app 134, schema XXCUS); `apex/` is
  frozen; never run `repos/tools/build_repos.py`. Pushing is allowed; PRs merge through the pipeline (section 3).
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

## 3. COMMON CI/CD pipeline (`.github/workflows/pipeline.yml`, scripts in `repos/common/deployment` - README there)
- Every PR to main starts one record in Actions: `<PR title>:<run number>` (title convention
  `<APP> <release>: <description>`). Jobs: **3** offline validation (lint, static, docs, build, APEXlang, PMD) -> **4** OCI
  setup (placeholder) -> **5** DB setup (start DB placeholder, bootstrap only when needed, backup schema `XXFUSION_BKP`)
  -> **6** deploy fresh (backup the data, remove, deploy, online validation) -> **7** upgrade (remove, deploy the last
  release, restore the data, upgrade once, nothing lost, online validation, drop the backup schema) -> **8** test users +
  DB tests (failures stop it) -> **9** finalize (gate, APEXlang export zip, draft release; merge by GitHub auto-merge)
  -> **10** error handling (PR comment + run summary, stop). A PR that does not touch COMMON runs jobs 3 and 9 only.
- **Merge**: `9 Finalize the PR` is the required check on main; Claude enables auto-merge on its PR (as the user), so
  GitHub merges when the check is green and the workflows on main (`release.yml`, docs) run. `release.yml` publishes the
  draft release `common-<N>` (the tested zip) when a PR that adds `repos/common/releases/<N>-*/` merges.
- Validation database: separate Always Free ADB (Jeddah), APEX 26.1.6, workspace XXCUS (schemas XXCUS + XXFUSION).
  Login: wallet + pipeline user `XXCI_DEPLOY` (proxy `XXCI_DEPLOY[XXFUSION]`, `lib/sql.sh`, connect line on stdin);
  ADMIN only for bootstrap and test users. Secrets in environment **Oracle DB Dev**: `VAL_DB_WALLET`, `VAL_DB_SERVICE`,
  `VAL_DB_ADMIN_PASSWORD`, `VAL_DB_CI_PASSWORD`, `VAL_DB_PASSWORD` (App Builder user XXCUS).
- Netlify is removed (user, 2 Nov 2026).
- KYC still uses `checks.yml` / `docs-check.yml` (only for `repos/kyc/**`); its own pipeline comes later.

## 4. Open items
- COMMON pipeline redesign (jobs 3-10) - first green run not yet confirmed; replaces PR #199.
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
