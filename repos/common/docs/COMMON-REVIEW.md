# COMMON review - unused, duplicates, alignment (25-Oct-2026)

Files only (no database), on the merged source with the generated dependency tree (`db/deploy/DEPENDENCIES.md`).
Nothing below is changed yet except item B1 (a duplicate the restructure itself created).

## A. Not used by COMMON
| # | Item | Type | Finding |
|---|---|---|---|
| A1 | `lov-dff-columns` (DFF RESERVED COLUMNS) | shared LOV | referenced by no page or code |
| A2 | `admin-app` (Administration - Application in Scope) | authorization | referenced by no page or component |
| A3 | `OUTLOOK_MESSAGES`, `SHAREPOINT_DRIVES`, `UCM_CONTENT` | REST data sources | referenced nowhere (prepared, never wired) |
| A4 | `xxfnd_retention_pkg` | package | no caller: no automation, job or page runs it, so retention never happens |
| A5 | `xxfnd_document_versions_v`, `xxfnd_integration_changes_v`, `xxfnd_qa_history_v` | views | no page or code reads them (only docs / comments) |
| A6 | `xxfnd_transmissions` | table | used only by tests; no page or package reads or writes it |
| A7 | `xxfnd_ui_pkg` | package | not used by COMMON itself, only by KYC (shared UI helper - keep, listed for information) |

All 86 pages are reachable (menu, list, link or branch); all task definitions, workflows, the email template and the
automations are used. Triggers are not listed (they fire on their table).

## B. Duplicates
| # | Item | Finding |
|---|---|---|
| B1 | 8 object files (`xxfnd_util_pkg`, `xxfnd_schema_pkg`, `xxfnd_audit_pkg`, `xxfnd_approval_pkg` spec/body, `xxfnd_user_roles_v`) | two identical copies made by the one-object-per-file restructure (install and upgrade variant of script 05) - **fixed**: one file each, scripts unchanged |
| B2 | Page LOV queries repeated inline instead of a shared LOV: setup columns (`xxfnd_setup_columns_v`, 3 variants in 2-5 pages), applications (2 variants, 2 pages each), notification templates (2 pages) | should be shared LOVs |
| B3 | `xxfnd_util_pkg.create_who_trigger` / `create_all_who_triggers`, `xxfnd_audit_pkg.create_audit_trigger`, `xxfnd_vpd_pkg.apply_policies` | thin wrappers of the same routines in `xxfnd_schema_pkg` - two entry points for one rule |

No duplicate shared LOVs, authorizations or page names. `unregister_application` in 10 packages is not a duplicate
(each component removes its own rows - one package per component).

## C. Not aligned with the vision / instructions
| # | Rule | Finding |
|---|---|---|
| C1 | COMMON has no KYC dependency | `xxfnd_user_pkg.party_details_editable` (authorization helper) calls KYC's `XXCMP_PARTY_PKG.CAN_EDIT_DETAILS` dynamically - KYC logic inside COMMON |
| C2 | same | `xxfnd_attach_pkg` (line ~934) falls back to application alias `'KYC'` when no application is in session |
| C3 | same; setup data per application | COMMON's seed script 17 creates 13 KYC lookup types (ENTITY_TYPE, PARTY_TYPE, CONTACT_TYPE, RELATIONSHIP_TYPE ...) and checks for `XXCMP_PARTIES` - KYC setup should be registered by KYC through COMMON routines |
| C4 | COMMON tests without KYC | 14 COMMON test scripts use KYC objects (`kyc_functions_test`, `r76_departments_test`, `r96_security_*`, `tasks_prep`, `viewonly_role`, `common_test_fixture(s)`, `test_users`, `admin_scope_test`, `upload_limits_test`, `r73_common_test`, `r92_flexfield_test`) |
| C5 | every page 2+ privileges (View/Create/Manage) | 10 pages use only *signed-in user*: 1 Home, 40 My Tasks, 43 Notifications, 45 Communications, 46 E-mail, 47 Attachments, 48 Document, 143 Information Request, 144 Configuration Change, 173 Give Feedback; 100 and 183 use *admin-area*; 50 Provide Information is public (one-time token, by design) - decision: self-service pages per user, or privileges |
| C6 | no files cut in parts | `lists.apx`, `lovs.apx`, `authorizations.apx` are still built from pieces at fixed offsets (same risk as the old DB scripts; the build now stops if they drift) |
| C7 | wording | KYC examples in comments (`xxfnd_dff_pkg`, `xxfnd_approval_pkg`, `xxfnd_config_tables`, `xxfnd_rfis`) |

Aligned: HTML in PL/SQL only in `xxfnd_dff_pkg` (documented exception); theme Redwood Light, users cannot change it;
no direct KYC data change in COMMON.

## Outcome - COMMON 108 / KYC 101 (fixes done)
- Removed: LOV `DFF_COLUMNS`, authorization `ADMIN_APP`, table `XXFND_TRANSMISSIONS` (dropped while empty, script 41a),
  the 5 wrapper routines (callers use `XXFND_SCHEMA_PKG`).
- Kept after checking: `XXFND_INTEGRATION_CHANGES_V` (read dynamically through `XXFND_CONFIG_TABLES.CHANGES_VIEW`),
  `XXFND_DOCUMENT_VERSIONS_V` and `XXFND_QA_HISTORY_V` (application-facing APIs), `XXFND_RETENTION_PKG` (placeholder for
  the planned retention), REST sources OUTLOOK_MESSAGES / SHAREPOINT_DRIVES / UCM_CONTENT and the SSO profile app items
  (planned integrations).
- Shared LOVs `ENABLED_APPLICATIONS`, `NOTIFICATION_TEMPLATES` on page 116.
- C1/C2/C3/C4/C7 done: no `XXCMP_PARTY_PKG` call, no `'KYC'` fallback, no KYC lookups in seed 17, KYC-dependent tests in
  `repos/kyc/tests/common-usage/`, generic comment examples. Rule moved to `XXCMP_PARTY_PKG.DETAILS_AUTHORIZED` (KYC 101).
- C5: self-service pages stay signed-in user only (decision).
- Left: the scheme name `KYC_USER` in `XXFND_USER_PKG.AUTHORIZED` (generic logic, name only; renaming touches KYC
  authorizations); the `RFI_STATUS` / `RFI_RECIPIENT_TYPE` / `RFI_CATEGORY` lookups are registered by KYC although COMMON's
  RFI reads `RFI_STATUS` - a standalone COMMON shows no status meaning (proposal: make them COMMON lookups).
