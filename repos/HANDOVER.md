# Handover - current state for a new chat (as of COMMON 113 / KYC 105)

Read this first, then `CLAUDE.md` (rules) and the requirements summary
https://claude.ai/artifact/AkQYLkw1WPgmCH1d8b8z9G (functional reference, updated up to COMMON 113).

## 1. Where things are
- Work only in `repos/common` (COMMON, app 135, schema XXFUSION) and `repos/kyc` (KYC, app 134, schema XXCUS).
  `apex/` is frozen. Never run `repos/tools/build_repos.py`.
- Build: `sh repos/common/build.sh --release N` (or `repos/kyc/build.sh`). Output `dist/app` + zip.
- Validate offline with the APEXlang validator (Oracle skills `apex/apexlang/26.1`) -> "Validation successful".
- DB scripts: `db/manifest.json` (file, install/upgrade sequence, units). Base table scripts create only when missing;
  every change is a checked step (`XXFND_DDL_PKG.ADD_COLUMN / DROP_COLUMN / ADD_CONSTRAINT / DROP_CONSTRAINT`).
- New pages must be added to `SOURCE-MAP.json` (whole file entry) or the build leaves them out.
- Each release: `repos/<app>/releases/NNN-name/` (README, run-release.sql, changed db + app files) and the zip.
- Git: branch `claude/adoring-galileo-8gd42b` re-created from `origin/main`, commit, push, PR, merge (merge method).
  Pushing and merging is allowed; never touch Netlify.
- No database is started; DB tests are written for the user's test database. Live server:
  https://g284ec8a23159dd-qddevdb1.adb.eu-amsterdam-1.oraclecloudapps.com/ords/r/xxcus/common (test users in
  `repos/common/db/admin/test-users.sql`, password Welcome#2026). The browser in the cloud session cannot open it
  (proxy certificate not trusted, permission refused) - live checks are done by the user.

## 2. Working rules (from the user)
- Issues first, then a plan, then approval - never code before "yes". Answers short and to the point.
- One package per component; no HTML in PL/SQL; OOTB APEX (Redwood Light, standard templates).
- COMMON data changes only through COMMON routines (application code parameter); COMMON is never duplicated;
  COMMON gaps go to `repos/common/docs/COMMON-ISSUES.md`.
- COMMON is finished first; KYC changes are made later in one go.
- Retention: keep as a placeholder - no change, no addition, no deletion.

## 3. Latest releases (all merged)
| Release | Content |
|---|---|
| COMMON 109 | Servers from APEX Remote Servers / Web Credentials; user lock / unlock |
| COMMON 110 | Purpose endpoint from REST Source Catalog services (`CATALOG_SERVICE_ID`) |
| COMMON 111 | Menu group page (page 100 per group); RFI lookups owned by COMMON; `KYC_USER` / `ADMIN_APP` schemes removed; servers_v install fix |
| COMMON 112 | Server linked to its APEX Remote Server (`REMOTE_SERVER_CODE`, name/URL live); `SOURCE_APPLICATION_ID` dropped; server REST Source Catalogs (`XXFND_SERVER_CATALOGS`); REST Data Sources list on the server; Fusion Objects removed (41c) |
| COMMON 113 | Fix page 121 (ORA-00937) and page 104 (grid); Process Catalogue one row per process; Process page 154; Approval Group page 155; approver type GROUP (`XXFND_APPROVAL_GROUPS` / `_MEMBERS`) |
| KYC 105 | Request stages (Draft > Submitted > Under Review > In Approval > Approved, plus Info Needed / Not Required / Rejected / Cancelled), requesting country, Assign (206), New Requests (200), requester KPIs, 201 two columns, 203 review, 205 submit popup |

## 4. To do after installing COMMON 112 / 113 (user, on the server)
- Open the FUSION server: pick APEX Remote Server `apex-fa-iabwbn-dev1-rest-apis`, the Fusion Web Credential and its
  REST Source Catalogs; save (URL shows, state OK).
- Run the DB tests: `features/integrations/tests/r109_servers_users_test.sql`, `r110_catalog_service_test.sql`,
  `r112_server_link_test.sql`, `tests/r111_common_pending_test.sql`, `features/approval-setup/tests/r113_approval_groups_test.sql`.
- Do not run COMMON 111+ with the current KYC: KYC's `kyc-user` authorization still calls `KYC_USER` (now false) -
  see C18 below.

## 5. Pending - agreed, not started (each needs its plan and approval first)
### KYC (the user does KYC "later in one go")
1. **C18** - KYC `kyc-user` scheme must call `xxfnd_user_pkg.authorized('APP_USER')`; deploy with COMMON 111+.
2. **One process per component** - KYC to use the COMMON 113 model: one approval process for the KYC case and one for
   the request, rules and approval groups on the Process page (today KYC has many risk-tier rules).
3. **L1 pipeline** - L1 KPIs / pipeline view of all stages at a glance (different from the requester KPIs).
4. **Stage gaps** - G2 cancel a request after submit; G4 return to the contributor; G5 notify the requester.
5. **New screening questions** - the 5 questions from the staging PDF; score >= 8 = KYC Required, else Not Required.
6. **Question display types** - drop-down list, radio buttons, check boxes, user entry field.
7. **Old tests** - KYC end-to-end tests still expect status IN_PROGRESS (replaced in KYC 105).
8. **C17** - request badge tones: COMMON `STATUS_TONE` holds KYC statuses; wanted: tone from the status lookup tag.

### COMMON issues still open in `COMMON-ISSUES.md`
- C13 delegations have no routine; C14 approval rules / role grants cannot be switched off and on by a routine;
  C15 an application cannot rename its own lookup values; C16 test-users script department codes (re-run needed).

### Parked by the user
- Retention two-stage review design (review then archive/delete, 30-day minimum review, reminders, flagged-records
  screen) - placeholder only until the user asks.

## 6. How the latest COMMON pieces work (quick reference)
- **API call** = Remote Server (URL) + Web Credential + REST Source Catalog service (endpoint).
  `XXFND_INTEGRATION_PKG.CALL`: catalog service endpoint on the purpose's server (host replaced), server credential
  else catalog credential; REST Data Source as fallback.
- **Server** (`XXFND_SERVERS`): `SERVER_CODE` (static ID) + `REMOTE_SERVER_CODE` (empty = same as code); name and URL
  read from the remote server in `XXFND_SERVERS_V`; Last Call / Error / Test logged under code or remote static ID.
- **Menu**: folders link to COMMON page 100 (`P100_GROUP` = entry code, cards from `XXFND_NAV_MENU_V`).
- **Approval**: process = approval type; rules -> levels (steps); level approver ROLE / USER / GROUP / REQUESTER;
  GROUP keeps the group code in `ROLE_CODE`; `GROUP_USERS` resolves members.
