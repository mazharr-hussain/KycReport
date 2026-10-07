# Patch 39 – shared objects only in XXFUSION; KYC uses synonyms (release 54)

## Why
Until now XXCUS kept its own copy of every shared `XXFND_` object (KYC's data), and XXFUSION had a second copy
installed by COMMON. From this release the shared objects and their data exist **only in XXFUSION**. XXCUS keeps the
KYC objects (`XXCMP_`) and a **synonym for each shared object**; XXFUSION grants XXCUS what it needs.

## What changes
- **COMMON (XXFUSION)**
  - Installs every shared script (01–15, 16h, 16j, …) and the new scripts:
    - `09c`: shared DDL that KYC scripts used to create — admin-console columns / index / view, and the
      integration-purposes approval trigger.
    - `19c`: `XXFND_SHARE_PKG`. `grant_to_applications` re-runs on every install / upgrade and grants each
      registered application schema (`XXFND_APPLICATIONS.SCHEMA_NAME`; KYC = XXCUS):
      - tables: SELECT (with grant option), INSERT, UPDATE, DELETE, REFERENCES;
      - views and sequences: SELECT;
      - packages and types: EXECUTE.

      `import_schema` performs the one-time move; `seed_common` holds COMMON's own access (script 20 calls it).
  - Shared code now works with an application's own objects:
    - `xxfnd_schema_pkg` (new, invoker rights) creates WHO / audit triggers and data-security policies in the
      caller's schema. The policy function is XXFUSION's `xxfnd_vpd_pkg`.
    - Approvals, Config Change Approvals, flexfields and the party-details authorization use owner-qualified
      names (`xxfnd_util_pkg.qualified`). User renames cover the application schemas.
- **KYC (XXCUS)**
  - New first script `03` (move and synonyms; see "What happens on the KYC import" below).
  - New script `19a`: grants XXFUSION SELECT / UPDATE on the XXCMP_ tables, SELECT on the views and EXECUTE on the
    packages (approvals, flexfields, user renames, the party-details rule).
  - Every other KYC script runs only when XXFUSION is ready and the move is done.
  - KYC no longer installs any shared table script. Its foreign keys to shared tables name `xxfusion.` (a foreign
    key cannot go through a synonym).
- `XXFND_SCHEMA_RELEASES` / `XXFND_DDL_PKG` stay local in each schema (release tracking per application).
- The admin screens still run in KYC (through the synonyms); they move to COMMON in the next patch.

## What happens on the KYC import
Script 03 runs first:
1. Checks that XXFUSION is ready (COMMON installed). If not, it reports **ORA-20902 ACTION NEEDED** and nothing
   else runs.
2. On the first import of this release:
   - keeps the definitions of the 8 foreign keys from XXCMP_ tables to shared tables;
   - grants XXFUSION SELECT on XXCUS's own copy;
   - calls `xxfusion.xxfnd_share_pkg.import_schema`. It checks every column exists in XXFUSION, replaces
     XXFUSION's shared rows with XXCUS's (same keys), compares the row counts, resets the identity counters,
     sets the schemas in XXFND_APPLICATIONS, re-applies COMMON's own access and records `MOVE_XXCUS`;
   - drops XXCUS's copy (shared tables, views, packages, types, sequences, XXFND_ jobs, flexfield views).
3. Creates a synonym for every shared object, including objects added by later releases.
4. Re-creates the foreign keys on the XXFUSION tables.
5. Re-points the data-security policies to XXFUSION's policy function.

## Deploy – application imports, in this order
1. **COMMON**: import `COMMON-Application-APEXlang_54.zip` from `COMMON-Install-Pack_54.zip` → parsing schema
   XXFUSION → Install Supporting Objects: Yes.
2. **KYC**: import `KYC-Compliance-Platform-APEXlang_54.zip` from `KYC-Install-Pack_54.zip` → replace 134 →
   Install Supporting Objects: Yes. The shared data moves once.

No ADMIN script is needed: XXFUSION already has the privileges, and the grants between the two schemas are made by
the imports.

## Tested (local Oracle 26ai + APEX 26.1; XXCUS and XXFUSION backed up with Data Pump first)
- COMMON upgrade scripts in XXFUSION: no errors, no invalid objects; 263 grants to XXCUS.
- KYC upgrade scripts in XXCUS, including the move: no errors, no invalid objects.
  - XXCUS keeps 79 synonyms plus the local release tracking.
  - XXFUSION has KYC's rows: 6 employees, 224 lookup values, 2 documents, roles and grants, plus COMMON's own role
    and grant.
  - 4 data-security policies now use XXFUSION.XXFND_VPD_PKG; 8 foreign keys now reference XXFUSION tables.
- Tests: `security_test` (row access per user through the shared policy), `workflow_test`, `party_test`,
  `request_party_test`, `monitoring_test`, `token_test` pass. Browser tests:
  - `kyc_ui` 26/26, `party_ui` 23/23, `request_party_ui` 24/24, `monitoring_ui` 14/14;
  - `admin_ui` and `common_ui` (ADMIN in, REQ2 refused);
  - `tasks_ui`: RFI response and a config-change approval, the latter through XXFUSION into the KYC table.
- Not caused by this change: `kyc_flow_test` stops at the report conclusion required since release 43 (outdated
  test). On the local instance the workspace e-mail quota had to be raised: the task "on create" e-mail fails when
  the quota is used up, and APEX then refuses to create the task.
