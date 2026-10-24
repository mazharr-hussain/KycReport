# COMMON 107 - Fusion Objects engine

Build: `releases/COMMON-Application-APEXlang_107.zip` (application version "Release 107"). COMMON only. Install COMMON
106 first. Built with `repos/common/build.sh --release 107`; checked with the APEXlang validation (no database run).

## What it adds
A metadata-driven engine to onboard Oracle Fusion BICC view objects and REST resources from live metadata (feature
FUSION_OBJECTS, module Integrations, pages 190-194). See `features/fusion-objects/README.md`.

| File | Purpose |
|---|---|
| db/xxfnd_fi_catalog.sql | harvested metadata catalog (BICC datastores, REST resources) |
| db/xxfnd_fi_objects.sql | onboarded objects: mode, status, schedule, storage, last sync |
| db/xxfnd_fi_attributes.sql | attributes of an object (selected, keys, business names) |
| db/xxfnd_fi_children.sql | REST child resources of an object |
| db/xxfnd_fi_versions.sql | metadata versions and their business views |
| db/xxfnd_fi_drift.sql | metadata drift (auto-applied / waiting for approval) |
| db/xxfnd_fi_runs.sql | run log |
| db/xxfnd_fi_meta_pkg.sql | harvester (BICC meta API, REST describe) |
| db/xxfnd_fi_gen_pkg.sql | generators (tables, versioned views, BICC configuration and job, REST query) |
| db/xxfnd_fi_registry_pkg.sql | registry and onboarding (create, select, mode, activate, pause / resume / retire) |
| db/xxfnd_fi_drift_pkg.sql | drift check, approve / reject, alerts |
| db/xxfnd_fi_run_pkg.sql | runtime (BICC extract + Object Storage load, REST replica, real-time / push) |
| db/40z-fusion-objects-setup.sql | messages, purpose FUSION_OBJECTS, feature and privileges, alert template, menu |
| app/pages/p00190 ... p00194 | Fusion Objects, Onboard Object, Object Detail, Drift Queue, Run Log |
| app/shared-components/automations/fusion-objects-run.apx | automation (every 15 minutes, installed disabled) |
| app/shared-components/rest-data-sources/fusion-root.apx | REST Data Source on the Fusion server root |
| app/shared-components/breadcrumbs.apx | breadcrumb entries of the pages |

Install / upgrade scripts 40a-40l, 40z (sequences 240-252).

## Deploy
1. App Builder > Import `COMMON-Application-APEXlang_107.zip` over COMMON (135), with Install Supporting Objects set to Yes.
2. Grant `EXECUTE on DBMS_CLOUD` to XXFUSION (if missing) and create the DBMS_CLOUD credential for Object Storage.
3. Servers (121): add the OBJECT_STORAGE server (region, namespace, credential static ID = the DBMS_CLOUD credential name).
4. Switch on the automation "Fusion Objects run".

## To check live (first use)
- BICC REST paths and JSON keys on your pod: `/biacm/rest/meta/offerings`, `/offerings/{id}/dataStores`,
  `/datastores/{id}?includeCustomization=true` (PUT with `isPopulate`), `/jobs` (create), `/jobs/{job}/schedules`
  (run now) and `/jobs/{job}/schedules/{request}` (status). They are constants in `XXFND_FI_META_PKG` and
  `XXFND_FI_RUN_PKG` (one place to adjust).
- BICC access of the Fusion credential (ORA-20360 on Harvest BICC when missing).
- The Object Storage bucket registered as BICC external storage, and the DBMS_CLOUD credential working
  (`DBMS_CLOUD.LIST_OBJECTS`).
- BICC extract files: zip / csv names containing the datastore name; primary-key extract files containing `pecsv`.
