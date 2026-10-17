# kyc-rules

Feature of KYC Compliance Platform. Copied as it is from the current application (no change).

## Uses (objects of these features are named in its files)
cases, common:attachments, common:audit-log, common:change-approvals, common:data-security, common:information-requests, common:integrations, common:lookups, common:roles-privileges, kyc-requests, parties

## Used by
cases, kyc-requests, parties

## Files
- `db/packages/xxcmp_doc_rule_pkg.sql`
- `db/packages/xxcmp_kyc_pkg.sql`
- `db/packages/xxcmp_risk_pkg.sql`
- `db/tables/xxcmp_answer_options.sql`
- `db/tables/xxcmp_approval_matrix.sql`
- `db/tables/xxcmp_attachment_rules.sql`
- `db/tables/xxcmp_conclusion_templates.sql`
- `db/tables/xxcmp_questionnaires.sql`
- `db/tables/xxcmp_questions.sql`
- `db/tables/xxcmp_risk_factors.sql`
- `db/triggers/xxcmp_answer_options_mc.sql`
- `db/triggers/xxcmp_answer_options_ver.sql`
- `db/triggers/xxcmp_attachment_rules_mc.sql`
- `db/triggers/xxcmp_risk_countries_mc.sql`
- `db/triggers/xxcmp_risk_factors_mc.sql`
- `db/triggers/xxcmp_risk_tiers_mc.sql`
- `db/views/xxcmp_config_changes_v.sql`
- `pages/p00138-mandatory-document-rules.apx`
- `pages/p00139-mandatory-document-rule.apx`
- `pages/p00160-questionnaires.apx`
- `pages/p00161-questionnaire.apx`
- `pages/p00162-question.apx`
- `pages/p00163-conclusion-templates.apx`
- `pages/p00164-conclusion-template.apx`
- `pages/p00165-approval-matrix.apx`
- `pages/p00167-risk-model.apx`
- `shared-components/lovs.apx`
- `tests/r74_risk_test.sql`
- `tests/r74_risk_ui.py`
