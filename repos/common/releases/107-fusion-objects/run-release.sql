-- COMMON 107 Fusion Objects: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/2460-table-xxfnd_fi_catalog.sql
@@db/2470-table-xxfnd_fi_objects.sql
@@db/2480-table-xxfnd_fi_attributes.sql
@@db/2490-table-xxfnd_fi_children.sql
@@db/2500-table-xxfnd_fi_versions.sql
@@db/2510-table-xxfnd_fi_drift.sql
@@db/2520-table-xxfnd_fi_runs.sql
@@db/2530-package-spec-xxfnd_fi_meta_pkg.pks
@@db/2540-package-body-xxfnd_fi_meta_pkg.pkb
@@db/2550-package-spec-xxfnd_fi_gen_pkg.pks
@@db/2560-package-body-xxfnd_fi_gen_pkg.pkb
@@db/2570-package-spec-xxfnd_fi_registry_pkg.pks
@@db/2580-package-body-xxfnd_fi_registry_pkg.pkb
@@db/2590-package-spec-xxfnd_fi_drift_pkg.pks
@@db/2600-package-body-xxfnd_fi_drift_pkg.pkb
@@db/2610-package-spec-xxfnd_fi_run_pkg.pks
@@db/2620-package-body-xxfnd_fi_run_pkg.pkb
@@db/2630-40z-fusion-objects-setup-01-xxfnd_util_pkg-set_install_mode.sql
