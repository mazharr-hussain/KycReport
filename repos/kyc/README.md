# KYC Compliance Platform (application 134, schema XXCUS)

Segregated from the current application under `apex/` (one folder per feature). Nothing was changed or fixed: every
file, statement or component is copied as it is, and `SOURCE-MAP.json` records where each source went
(`python3 ../verify.py` rebuilds every source from its pieces and compares it byte for byte).

## Layout
- `features/<feature>/` - its pages, its shared components (LOVs, authorizations, lists, task definitions, workflows,
  automations used only by it), its database objects (`db/tables`, `db/packages`, `db/views`, `db/sequences`,
  `db/types`, `db/triggers`, `db/seed`) and its tests; its README lists what it uses and what uses it.
- `app/` - the application parts every feature uses: application.apx, Global Page 0, login, page groups,
  authentications, navigation lists, themes, static files, plugins, deployments.
- `db/manifest.json` - the install / upgrade order (the original entries); `db/scripts/` - the statements that belong to
  a whole script, not one object (release markers, registration, checks); `db/admin/` - administrator scripts.
- the install framework (deployment framework, prerequisites, triggers, recompile) is COMMON's, in
  `common/db/framework/`: KYC runs it from there (no copy).
- `docs/` - install notes; `tests/` - tests of the whole application.

## Build
`./build.sh [--release N]` - the one build, `common/tools/build.py` (no build logic in this repository - it is COMMON's); output in `dist/` (not kept in git).

## Not copied
- the generated install / upgrade scripts of `supporting-objects/` (the build makes them from the database scripts).
- History and tooling stay in `apex/`: release zips, patches, tools, ARCHITECTURE.md, CHANGELOG.md, PROJECT.md.
