# KYC Compliance Platform – architecture and dependency map

APEX 26.1 APEXlang app (alias KYC, workspace XXCUS). Source: `apex/src`; database scripts: `apex/db` (copied into
`src/supporting-objects/{install,upgrade}-scripts` by `tools/build.py`). Every db script is idempotent.
Prefixes: `XXFND_` = platform (reusable), `XXCMP_` = KYC business.

## Layers
```
Pages (src/pages)  ──>  XX*_PKG (db)  ──>  tables (db)
   │                       ▲
   ├─ authorizations: FEATURE privilege V/C/M (xxfnd_privilege_pkg), one generic scheme per level
   └─ row security: VPD policy (xxfnd_vpd_pkg) on business tables, rules in XXFND_DATA_SECURITY_RULES
Workflows / task definitions / automations (src/shared-components) ──> same packages
```
- Trusted reads past VPD: `xxfnd_vpd_pkg.begin_trusted/end_trusted`; background jobs are trusted (BG_JOB_ID).
- Requesters cannot read XXCMP_PARTIES: party data reaches them as JSON from trusted functions (`json_table`).
- Admin changes to rules go through approval: `xxfnd_config_approval_pkg` + CONFIG_CHANGE task (page 172).

## Features (page → packages → tables); change one, check the others in its row
| Feature | Pages | Packages | Main tables | Workflow / tasks / automation |
|---|---|---|---|---|
| **Requests** | 200 list, 201-203 wizard, 205 request | xxcmp_request_pkg, xxcmp_kyc_pkg, xxfnd_attach_pkg | xxcmp_requests, xxcmp_request_answers, reads xxcmp_parties, xxcmp_questionnaires/questions/answer_options | KYC_REQUEST wf (v1.1 active, v1.0 for old runs): COUNTERPARTY_MATCH → DOC_CHECKLIST_REVIEW → `create_case` |
| **Cases** | 210, 211 case, 212 decision, 213 screening, 214 UBO, 215 doc verif., 216 create, 217 report | xxcmp_case_pkg | xxcmp_cases, _case_decisions, _screenings, _doc_verifications, _ubo_determinations, _case_notes; xxcmp_approval_matrix | KYC_CASE wf: CASE_INVESTIGATION → CASE_APPROVAL (1-2 levels) |
| **Parties** | 20, 21, 22 contacts, 23 relationships | xxcmp_kyc_pkg, xxfnd_dff_pkg, xxfnd_attach_pkg | xxcmp_parties, _party_contacts, _party_relationships | – |
| **RFI** | 30-33 | xxcmp_kyc_pkg | xxcmp_rfis | RFI_RESPONSE, RFI_REVIEW |
| **Monitoring** | 220 watchlist, 221 alerts, 222 reassess, 225-226 alert rules, 230 dashboard | xxcmp_monitor_pkg | xxcmp_alerts, xxcmp_alert_rules, view xxcmp_watchlist_v | automation kyc-monitoring (daily) |
| **Tasks** | 40 My Tasks, 41 monitor, 42 details, 44-45 workflows, 145-147 deadlines | xxfnd_task_pkg, xxfnd_notify_pkg | xxfnd_task_settings, xxfnd_task_alerts, xxfnd_wf_delegations | automation task-deadlines |
| **Attachments** | 90 add, 91 details, 130-139 admin | xxfnd_attach_pkg, xxfnd_attach_store_pkg | xxfnd_documents*, xxfnd_attached_documents, xxfnd_attachment_functions (limits per page), xxfnd_document_categories (limits per category), xxfnd_storage_config, xxcmp_attachment_rules | – |
| **Questionnaires** | 160-164, 165 approval matrix | xxfnd_config_approval_pkg | xxcmp_questionnaires, _questions, _answer_options, _conclusion_templates | CONFIG_CHANGE |
| **Flexfields** | 150-153 | xxfnd_dff_pkg, xxfnd_dff_setup_pkg | xxfnd_value_sets, xxfnd_df_* | – |
| **Security** | 103-108 users/roles/SoD, 180-182 data security & privileges, 10020-10023 | xxfnd_security_pkg, xxfnd_privilege_pkg, xxfnd_vpd_pkg | xxfnd_employees, _roles, _user_roles, _sod_rules, _features, _privileges, _role_privileges, _feature_pages, _data_security_rules | automation fusion-hcm-sync |
| **Admin misc** | 100 menu, 101-102 lookups, 109-115, 120-125 integration | xxfnd_util_pkg, xxfnd_audit_pkg | xxfnd_lookup_*, notification templates, audit log, retention, integration tables | – |

## Reverse map (table / package → who depends on it)
- **xxcmp_requests**: pages 200-205; xxcmp_request_pkg; KYC_REQUEST wf; COUNTERPARTY_MATCH, DOC_CHECKLIST_REVIEW; xxcmp_case_pkg (create_case reads it); dashboard 230.
- **xxcmp_parties**: 20-23, 201 (via party_directory_json), 205 (merge), 211, 220 watchlist; xxcmp_request_pkg (link_party/resolve_match), xxcmp_case_pkg, xxcmp_monitor_pkg.
- **xxcmp_questions / answer_options**: 160-162, 202 (`questionnaire_html`, `kycQuestionnaire` in kyc-app.js), 211 officer answers; intake scoring in xxcmp_request_pkg.evaluate.
- **xxcmp_cases**: 210-217, 220-222, 230; xxcmp_case_pkg, xxcmp_monitor_pkg; KYC_CASE wf.
- **xxfnd_task_pkg**: every workflow/task definition, page 40-47, 145-147, task-deadlines automation.
- **xxfnd_attach_pkg**: 21, 31, 33, 90, 91, 203, 205, 211 (upload limits via check_upload).
- **xxfnd_privilege_pkg / authorizations.apx**: every page (2+ privileges per page).
- **xxfnd_lookup_values**: nearly every LOV; `lookup_meaning` is result-cached.

## Tooling
- Page generators: `tools/pagekit.py` (shared helpers), `pages_chunk5.py` (200-217), `pages_chunk6.py` (220-230),
  `workflows_chunk5.py`. After running `pages_chunk5.py`, restore pages not in scope (`git checkout` them).
- Build: `python3 tools/build.py [--release N]`; cross-check: `python3 tests/rules.py src <schema.json> <out.json>`.
- Tests per feature: requests `request_party_test.sql`/`request_party_ui.py`, flow `kyc_flow_test.sql`/`kyc_ui.py`,
  monitoring `monitoring_*`, upload `upload_limits_*`, security `security_test.sql`, workflow `workflow_test.sql`.
- Patches for the user's environment: `apex/patches/NN-<feature>/` (db script + `app/` files + README) and a zip.
