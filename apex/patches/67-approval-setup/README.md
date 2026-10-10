# Patch 67 - Common Approval Setup (rules, conditions, approvers, ad-hoc) (release 74)

## What changes
- COMMON 15d: Approval Setup - types, rules with conditions, approver steps, ad-hoc approvers
  (XXFND_APPROVAL_TYPES / _RULES / _RULE_CONDS / _RULE_STEPS / _TXNS / _TXN_STEPS, XXFND_APPROVAL_RULE_PKG); pages
  148 (rules) and 149 (rule). APEX Workflow stays the engine.
- The setup-change approval (maker-checker) is one package, XXFND_APPROVAL_PKG (XXFND_CONFIG_APPROVAL_PKG dropped).
- KYC 16l: the request and case approvals use the setup (today's paths and matrix copied as rules); the Approval Paths
  page 166 is removed and page 165 keeps the SAR gate only; the case workflow loops any number of levels.

## Files
- `db/05-core-packages-part-1-of-2-upgrade.sql`
- `db/05-core-packages-part-1-of-2.sql`
- `db/06-core-packages-part-2-of-2.sql`
- `db/15d-approval-setup.sql`
- `db/18d-workflow-platform.sql`
- `app/KYC/pages/p00139-mandatory-document-rule.apx`
- `app/KYC/pages/p00162-question.apx`
- `app/KYC/pages/p00165-approval-matrix.apx`
- `app/KYC/pages/p00172-review-change.apx`
- `app/KYC/shared-components/task-definitions/CONFIG-CHANGE.apx`
- `app/KYC/shared-components/workflows/KYC-CASE.apx`
- `app/COMMON/pages/p00123-integration-purpose.apx`
- `app/COMMON/pages/p00148-approval-setup.apx`
- `app/COMMON/pages/p00149-approval-rule.apx`
- `app/COMMON/shared-components/breadcrumbs.apx`

Files shared with other release 74 parts are listed once, in the patch of their latest change.

## Deploy (release 74, in this order)
The release zips carry every patch of release 74 (65-75); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_74.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_74.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   Or, instead of both imports, run `COMMON-Application-SQL-Install_74.sql` then
   `KYC-Compliance-Platform-SQL-Install_74.sql` as ADMIN in SQL Developer Web (see each `install/<app>/INSTALL.md`).
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
