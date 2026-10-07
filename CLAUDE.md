# Working rules (from the user)

- Work **feature by feature** (screen by screen with its own db components). Do not fix or refactor anything outside
  the feature asked for; no long unrequested work. Mention other issues briefly instead of fixing them.
- Before changing a feature, check `apex/ARCHITECTURE.md` for its dependencies in both directions
  (what it uses and what uses it), and keep that file up to date when a feature changes.
- Deliver each feature as a small deployable patch: `apex/patches/NN-<feature>/` + zip (db script, changed app
  files under `app/`, README with deploy steps), on top of the latest release.
- Do not guess table or column names (ask for DDL); keep component IDs unless a fix needs a change.
- UI: Universal Theme with the **Redwood Light** theme style only (users cannot switch styles); use its standard templates.
- Rules: OOTB APEX first; access/admin changes from the application console; every page has 2+ privileges
  (View/Create/Manage) plus data security; reusable patterns; deploy in chunks.
- Test only what the feature touches (its db test + browser test).
- Layout: everything APEX lives under `apex/`, which is the SQLcl project root (`apex/.dbtools/`,
  `apex/src/database/xxcus/...`, `apex/dist/`); the APEX app is `apex/src/database/xxcus/apex_apps/f134`; `apex/db` holds the idempotent install/upgrade scripts (source of truth for DB).
- Database: one APEX workspace (XXCUS). XXCUS is the workspace's default (primary) schema and the parsing schema
  of the business apps (KYC = app 134); **XXFUSION** is the schema for Fusion web-service data and the COMMON
  application (shared security, setup, workflow), source `apex/src/database/xxfusion/apex_apps/f135`.
- **Golden rule: no Netlify.** Do not deploy, publish or trigger anything on Netlify (no Netlify builds,
  deploys or previews, no changes to `netlify.toml`) until the user clearly instructs it.
- **KYC frozen:** do not modify the KYC application (f134, its KYC-only db scripts, its zip) until the COMMON
  application is finished, unless the user clearly instructs it. Build and release COMMON only
  (`python3 apex/tools/build.py --release N --app COMMON`).
