# KYC Compliance Platform – SQLcl 26.x project

Created with SQLcl 26.2 `project init -name kyc -schemas XXCUS` and `project export` (APEX 26.1, Oracle AI Database 26ai).

```
.dbtools/                         project config (project.config.json: connection name, export options), filters
src/database/xxcus/
  apex_apps/f101/                 the APEX application in APEXlang (pages/, shared-components/, supporting-objects/)
  tables/ views/ package_specs/ package_bodies/ triggers/ indexes/ sequences/ ref_constraints/ comments/
                                  one file per database object (exported DDL, for reading/compare)
src/database/sys/object_grants/   grants the schema needs
dist/                             releases produced by `project stage` / `project release` (empty for now)
apex/db/                          idempotent install + upgrade + seed scripts (what really deploys the database)
apex/patches/                     small per-feature patches (db script + changed app files + README)
apex/tools/  apex/tests/          generators/build and tests
```

## Open in VS Code or Visual Studio 2022
1. Clone the repo (or unzip the project zip) and open the folder.
2. Edit pages in `src/database/xxcus/apex_apps/f101/pages/*.apx`, packages in `apex/db/*.sql`.
3. Deploy with SQLcl (VS Code: Oracle SQL Developer extension has it; Visual Studio: install SQLcl separately):
   - database: `@apex/db/<script>.sql` (or the feature patch script)
   - application: `apex validate -input src/database/xxcus/apex_apps/f101` then
     `apex import -input src/database/xxcus/apex_apps/f101 -id <app id>`
   - or `python3 apex/tools/build.py --release N` and import `apex/KYC-Compliance-Platform-APEXlang_N.zip` in App Builder.
4. Set your own connection name in `.dbtools/project.config.json` (`connectionName`), then `project export` refreshes
   `src/database/xxcus/` from your database.
