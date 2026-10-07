# Patch 33 – shared code no longer names KYC objects (release 48)

Step 1 of the common module (the shared XXFND_ code moves to the XXFUS schema later). No screen change.

## What changes
- **XXFND_CONFIG_TABLES** (new registry): each application registers its configuration tables – configuration
  audit (`AUDIT_FLAG`) and maker-checker (`APPROVAL_FLAG`, key column, approval unit `UNIT_TABLE` /
  `UNIT_KEY_COLUMN`, and the view of its pending changes `CHANGES_VIEW`).
  - Shared tables registered under the new application **COMMON** (22 tables; integration purposes under
    maker-checker, view `XXFND_INTEGRATION_CHANGES_V`).
  - KYC registers its own (18e): questionnaires, questions, answer options (approved per question), conclusion
    templates, approval matrix, mandatory document rules; view `XXCMP_CONFIG_CHANGES_V`.
- The shared code reads the registry instead of naming KYC tables: configuration audit triggers
  (`xxfnd_audit_pkg`), maker-checker key column (`xxfnd_approval_pkg`, now with DBMS_ASSERT), Config Change
  Approvals (`xxfnd_config_approval_pkg`), and the views `XXFND_CONFIG_CHANGES_V` / `XXFND_PENDING_APPROVALS_V`
  (table function `xxfnd_approval_pkg.config_changes` over every registered view).
- KYC objects handled by KYC scripts: the RFI table changes (from 15 to 16b) and the KYC row-access rules
  (parties, RFIs; from 18b to 18e).
- New application row **COMMON** in XXFND_APPLICATIONS.

## Deploy – application import only
**App Builder → Import** `KYC-Compliance-Platform-APEXlang_48.zip` → **Replace Existing Application** 134 →
**Install Supporting Objects: Yes**.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- All 37 upgrade scripts in APEX order: no errors, no invalid objects; registry: COMMON 22 tables, KYC 6.
- `workflow_test.sql`: mandatory-document-rule change → CONFIG_CHANGE task, maker cannot approve, HOC approves.
- Question change: 2 answer options → one pending change `XXCMP_QUESTIONS:<id>` and one task.
- `kyc_ui.py` 26/26, `party_ui.py` 23/23, `request_party_ui.py` 24/24; `tasks_ui.py` runs through (HOC sees the
  change with Approve / Reject, the maker does not).
