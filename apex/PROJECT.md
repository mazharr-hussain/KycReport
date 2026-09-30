# KYC Compliance Platform – SQLcl 26.x project (everything under `apex/`)

Created with SQLcl 26.2 `project init -name kyc -schemas XXCUS` and `project export` (APEX 26.1, Oracle AI Database 26ai).

The SQLcl project root is the `apex/` folder: open `apex/` in VS Code / Visual Studio and run SQLcl from there.

```
apex/
.dbtools/                         project config (project.config.json: connection name, export options), filters
src/database/xxcus/
  apex_apps/f134/                 the APEX application in APEXlang (pages/, shared-components/, supporting-objects/)
  tables/ views/ package_specs/ package_bodies/ triggers/ indexes/ sequences/ ref_constraints/ comments/
                                  one file per database object (exported DDL, for reading/compare)
src/database/sys/object_grants/   grants the schema needs
dist/                             releases produced by `project stage` / `project release` (empty for now)
db/                               idempotent install + upgrade + seed scripts (what really deploys the database)
patches/                          small per-feature patches (db script + changed app files + README)
tools/  tests/                    generators/build and tests
```

## Open in VS Code or Visual Studio 2022
1. Clone the repo (or unzip the project zip) and open the folder.
2. Edit pages in `src/database/xxcus/apex_apps/f134/pages/*.apx`, packages in `db/*.sql`.
3. Deploy with SQLcl (VS Code: Oracle SQL Developer extension has it; Visual Studio: install SQLcl separately):
   - database: `@db/<script>.sql` (or the feature patch script)
   - application: `apex validate -input src/database/xxcus/apex_apps/f134` then
     `apex import -input src/database/xxcus/apex_apps/f134 -id <app id>`
   - or `python3 tools/build.py --release N` and import `KYC-Compliance-Platform-APEXlang_N.zip` in App Builder.
4. Set your own connection name in `.dbtools/project.config.json` (`connectionName`), then `project export` refreshes
   `src/database/xxcus/` from your database.
