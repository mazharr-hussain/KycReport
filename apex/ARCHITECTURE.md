# KYC Compliance Platform – architecture and dependency map

APEX 26.1 APEXlang app (ID 134 set in `f134/deployments/default.json`, alias KYC, workspace XXCUS). SQLcl 26.x project rooted at `apex/` (see `apex/PROJECT.md`):
app source `apex/src/database/xxcus/apex_apps/f134` (APEXlang); schema DDL per object `apex/src/database/xxcus/<type>/` (exported
reference); install/upgrade + seed scripts `apex/db` (copied into the app's `supporting-objects/` by `apex/tools/build.py`). Every db script is idempotent.
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
| **Requests** | 200 list (Status, KYC Required, Pending With, Action Date; hidden: type, score, who columns), 201 step 1 = region *Request* + *Counterparty* (existing approved party, or new in the **common party region**) + possible matches (warning), 202 questionnaire, 203 documents & submit, 205 request (status fields, party card, Merge a duplicate, checklist decision, Respond / Cancel for the requester) | xxcmp_request_pkg (save_request, request_error, submit, cancel, info_requested / info_submitted, pending_with, kyc_required), xxcmp_party_pkg (put_party, party_error), xxcmp_kyc_pkg, xxfnd_attach_pkg | xxcmp_requests (statuses DRAFT, IN_PROGRESS, INFO_NEEDED, APPROVED, REJECTED, CANCELLED; last_action_date; contact_* hidden by build option REQUEST_CONTACT); creates xxcmp_parties (party_status PENDING) with the request; reads xxfnd_employees (department), xxcmp_attachment_rules, xxcmp_questionnaires/questions/answer_options | KYC_REQUEST wf (v1.2 active): Evaluate intake → KYC required? → DOC_CHECKLIST_REVIEW (task actions: Request / Submit Information set INFO_NEEDED / IN_PROGRESS) → `create_case` (request + party Approved) or reject (party Rejected); not required / auto-approved → request + party Approved |
| **Cases** | 210, 211 case, 212 decision, 213 screening, 214 UBO, 215 doc verif., 216 create, 217 report | xxcmp_case_pkg | xxcmp_cases, _case_decisions, _screenings, _doc_verifications, _ubo_determinations, _case_notes; xxcmp_approval_matrix | KYC_CASE wf: CASE_INVESTIGATION → CASE_APPROVAL (1-2 levels) |
| **Parties** | 20 list (IR, primary report shows Number, Name, Type, Reg./ID No., Country, Email, Phone, Party Status, Next KYC Date, Enabled, Edit; the rest hidden but available), 21 party (common region read only; Edit → Edit Details (24) + Add buttons; contacts and owners as IRs, who columns hidden; merge from Possible Matches), 22 contact person, 23 owner / officer (existing, or new in the common region; ownership % rule), 24 Party dialog (common region + additional information) | xxcmp_party_pkg (party_error, save_party, put_party, load_items, relationship_error, set_status, merge_parties, card_html; db/16e), xxcmp_kyc_pkg, xxfnd_dff_pkg, xxfnd_attach_pkg | xxcmp_parties (shared columns per type: jurisdiction = country / nationality, registration_number = reg. / ID no., entity_type = entity / ID type, incorporation_date = incorporation / birth date; party_status, next_kyc_date, email, phone, website, fax, merged_into_party_id; db/16d, 16f), _party_contacts (contact persons; one primary), _party_relationships | – |
| **RFI** | 30-33 | xxcmp_kyc_pkg | xxcmp_rfis | RFI_RESPONSE, RFI_REVIEW |
| **Monitoring** | 220 watchlist, 221 alerts, 222 reassess, 225-226 alert rules, 230 dashboard | xxcmp_monitor_pkg | xxcmp_alerts, xxcmp_alert_rules, view xxcmp_watchlist_v | automation kyc-monitoring (daily) |
| **Tasks** | 40 My Tasks, 41 monitor, 42 details, 44-45 workflows, 145-147 deadlines | xxfnd_task_pkg, xxfnd_notify_pkg | xxfnd_task_settings, xxfnd_task_alerts, xxfnd_wf_delegations | automation task-deadlines |
| **Attachments** | 90 add, 91 details, 130-139 admin | xxfnd_attach_pkg, xxfnd_attach_store_pkg | xxfnd_documents*, xxfnd_attached_documents, xxfnd_attachment_functions (limits per page), xxfnd_document_categories (limits per category), xxfnd_storage_config, xxcmp_attachment_rules | – |
| **Questionnaires** | 160-164, 165 approval matrix | xxfnd_config_approval_pkg | xxcmp_questionnaires, _questions, _answer_options, _conclusion_templates | CONFIG_CHANGE |
| **Flexfields** | 150-153 | xxfnd_dff_pkg, xxfnd_dff_setup_pkg | xxfnd_value_sets, xxfnd_df_* | – |
| **Security** | authentication: Oracle Database Accounts (current; Oracle APEX Accounts kept); 103-108 users/roles/SoD, 180-182 data security & privileges, 10020-10023 | xxfnd_security_pkg, xxfnd_privilege_pkg, xxfnd_vpd_pkg | xxfnd_employees, _roles, _user_roles, _sod_rules, _features, _privileges, _role_privileges, _feature_pages, _data_security_rules | automation fusion-hcm-sync |
| **Admin misc** | 100 menu, 101-102 lookups, 109-115, 120-125 integration | xxfnd_util_pkg, xxfnd_audit_pkg | xxfnd_lookup_*, notification templates, audit log, retention, integration tables | – |

## Reverse map (table / package → who depends on it)
- **xxcmp_requests**: pages 200-205; xxcmp_request_pkg; KYC_REQUEST wf; COUNTERPARTY_MATCH, DOC_CHECKLIST_REVIEW; xxcmp_case_pkg (create_case reads it); dashboard 230.
- **Common party components** (change once, used everywhere): the **party form = region `party-form` on the Global Page (page 0)**, items P0_PARTY_*, shown on 21 (read only), 23 (new owner), 24 (Party dialog), 201 (new counterparty); pages fill it with `xxcmp_party_pkg.load_items` and save with `save_party` / `xxcmp_request_pkg.save_request`; rules in `party_error`; labels follow the type (page 0 dynamic action). Card `xxcmp_party_pkg.card_html` (region `party_card`) on 205, 211 (with Edit Party → 24), 212, 222. A new party field goes into: xxcmp_parties (16d), the page 0 region, `load_items` / `put_party` / `party_error`, `card_html`.
- **xxcmp_parties.party_status**: PENDING when created from a request (201) → APPROVED with the request (`create_case`, `close_without_case`), REJECTED / CANCELLED with it (`reject`, `cancel`, switching to an existing party); 205 merge region only for a Pending party; 201 existing-party list only APPROVED.
- **xxcmp_parties.next_kyc_date**: set by `xxcmp_case_pkg.close_case` (approved: risk tier months, PEP cap; rejected: cleared); shown on 20, 21, card.
- **xxfnd_employees.department_name**: default requesting department on 201 (`xxcmp_request_pkg.default_department`).
- **xxcmp_attachment_rules** (Mandatory Document Rules, pages 138-139): request submit (`submit_error`), 205 checklist, case approval.
- **xxcmp_party_contacts** (contact persons; CONTACT_TYPE / CONTACT_VALUE dropped in 16f): 21-22; `xxcmp_request_pkg.save_request` (the hidden request contact → primary contact person); RFI to an external party (page 32 recipient list, `xxcmp_kyc_pkg` send: the person's email).
- **merge_parties** re-points: xxcmp_requests, _cases (closed too: `xxcmp_cases_lock` allows a party-only change), _screenings, _alerts, _case_notes, _ubo_determinations, _party_contacts, _party_relationships, attachments (XXCMP_PARTIES).
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
  Since release 23, pages 0, 20-24 and 200-205 are edited directly (the generators no longer match them: do not
  regenerate them).
- Build: `python3 tools/build.py [--release N]`; cross-check: `python3 tests/rules.py src <schema.json> <out.json>`.
- Tests per feature: requests `request_party_test.sql`/`request_party_ui.py`, flow `kyc_flow_test.sql`/`kyc_ui.py`,
  monitoring `monitoring_*`, upload `upload_limits_*`, security `security_test.sql`, workflow `workflow_test.sql`.
- Patches for the user's environment: `apex/patches/NN-<feature>/` (db script + `app/` files + README) and a zip.
