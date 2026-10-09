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
- **Golden rule: issues, then plan, then approval.** Collect all the issues the user reports first; when the user
  confirms the list is complete, propose a plan; start nothing without the user's approval of that plan.
- **Golden rule: no install error, ever (no ORA-00955).** Base table scripts (01-04) create a table, with its indexes
  and comments, only when it is missing (`XXFND_DDL_PKG.CREATE_TABLE`); an existing table is left as it is. Every
  change to an existing object is a checked step in a later numbered script (`XXFND_DDL_PKG.ADD_COLUMN`,
  `DROP_COLUMN`, `ADD_CONSTRAINT`, `DROP_CONSTRAINT`, `ENSURE_INDEX`, `DROP_INDEX`, `ENSURE_SEQUENCE`), listed for
  install and upgrade, so every database gets exactly what it is missing and a re-run does nothing. Never edit a base
  CREATE to change an existing table. Test every release with a fresh install, an install over existing objects,
  an upgrade, a re-run, and the App Builder import screen.
- **Golden rule: one package per component, business logic in its own place.** Each component has its own package
  (request logic in the request package, case logic in the case package, party logic in the party package, and so on);
  a component never holds another component's logic. When one component needs another's logic, it calls that
  component's procedure / function - never a copy - so each rule lives in one place and is shared. Logic common to
  every component (e.g. workflow start / end / state, the RFI workflow and its loop, tasks, notifications) lives once in
  COMMON; what is specific to a component (its screens, its validations, invoking the common workflow, its own rules)
  stays in that component's package. Keep shared things common to avoid duplication, and component things separate
  for better management. Changes to this structure still follow the issues, plan and approval rule.
- **Golden rule: no HTML in PL/SQL.** Build the UI with APEX components (classic / interactive reports, cards,
  template components, forms, display items, standard region templates) fed by SQL; packages return data, not markup.
  HTML is generated in PL/SQL only when no APEX component can do the job, and then the reason is written in a comment
  next to it.
- **COMMON first:** the KYC freeze (until COMMON was finished) ended with release 68 (approved plan: clean script,
  COMMON screens, data move, KYC uses COMMON). Shared setup screens live in COMMON only; KYC links to them
  (XXFND_ADMIN_SCOPE_PKG.SETUP_PAGE_URL). Build one app with `python3 apex/tools/build.py --release N --app COMMON`.
