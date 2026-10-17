# COMMON issues found by KYC (for the COMMON team)

KYC does not change COMMON and does not duplicate COMMON components (golden rule). Each issue below was found while
adapting KYC (releases 87-91) to COMMON 86. KYC uses COMMON as it is; the COMMON team fixes these in COMMON.

## C1 - Business users of an application cannot open COMMON's shared user pages (blocking)
- **Where:** `XXFND_USER_PKG.AUTHORIZED('APP_USER')` (apex/db/16j-user-pkg.sql), used by COMMON's application
  authorization `app-user` (f135 `shared-components/authorizations.apx`, evaluated on every page view).
- **Rule today (since COMMON 71):** in COMMON, APP_USER is true only for a Common Administrator
  (`XXFND_APPLICATION_PKG.IS_COMMON_ADMIN`) or a delegated administrator (`DELEGATED_ANY`).
- **Effect:** KYC's menu and pages link to COMMON's shared pages: My Tasks (40), E-mail (46), Information Request (143)
  and Feedback (173). A KYC requester or officer (for example REQ1, OFFICER1) who follows such a link gets
  "You do not have access to this application. Ask an administrator to grant you a role." A KYC user who is also a
  COMMON administrator (ADMIN) gets in.
- **Seen in:** KYC browser tests kyc88_shared_ui (REQ1 My Tasks), kyc89_rfi_ui (Information Request), r74_email_ui
  (Send E-mail), r75_ui, kyc_ui and request_party_ui (task steps open My Tasks as a business user), r74_risk_ui.
- **Needed:** a user who has a privilege in any registered application may open COMMON's shared user pages; every
  other COMMON page stays for IT and delegated administrators.

## C2 - A cancelled configuration change cannot be submitted again
- **Where:** `XXFND_APPROVAL_PKG.REQUEST` and the CONFIG_CHANGE workflow (COMMON 84).
- **Effect:** after a cancel, the CONFIG_CHANGE workflow of the row stays faulted; submitting the same change again is
  refused until the faulted workflow is removed by hand.
- **Seen in:** r74_risk_test ("submitted: one approval task for the factors") on a database where an earlier run left
  the workflow faulted.

## C3 - COMMON's script 17 rewrites KYC's lookups on every COMMON upgrade
- **Where:** apex/db/17 (runs for COMMON).
- **Effect:** an administrator's change to a KYC lookup value (meaning, order, enabled) is lost after a COMMON upgrade.
  KYC registers its lookups itself (18h, REGISTER_LOOKUP_*), which keeps administrator changes.
- **Needed:** 17 leaves other applications' lookups alone.

## C4 - DELEGATED_URL points to KYC page 98, which no longer exists
- **Where:** `XXFND_APPLICATION_PKG.DELEGATED_URL`.
- **Effect:** the "managed in the application" link of a delegated function opens "page not found" in KYC.
- **Needed:** the link goes to the function's page in COMMON (or to a page the application registers).

## C5 - Information Request page 143: no documents, no due dates, no task settings
- **Where:** f135 page 143, `XXFND_RFI_PKG`, workflow RFI.
- **Effect:** documents asked for in an information request cannot be attached or seen on the page; information
  requests have no due date and no task setting, so no deadline reminders. KYC's case documents block (RFI_DOCUMENTS
  on KYC_CASE) is a workaround on the case side only.

## C6 - E-mail page 46 has no list of the party's contacts
- **Where:** f135 page 46.
- **Effect:** the sender types the recipient address by hand; the contacts the application already holds (KYC party
  contacts) cannot be picked.
- **Needed:** an optional recipient list the calling application passes (entity and key), or a registered contact
  source.

## C7 - Application settings of another application cannot be changed from COMMON
- **Where:** `XXFND_APP_SETTING_PKG.SET_VALUE` (apex/db/21d) refuses an application other than the running one
  (APEX changes the settings of the running application only).
- **Effect:** KYC's settings (MAIL_FROM, ATTACH_*, FUSION_*, and from release 91 CASE_SLA_DAYS, PEP_REVIEW_MONTHS,
  REVIEW_LEAD_DAYS) cannot be changed on COMMON's Application Settings screen; today only in App Builder (Shared
  Components > Application Settings).
- **Needed:** a way for COMMON's screen to set another registered application's settings (for example through
  `APEX_APP_SETTING` in a session of that application).

## C8 - A page registration cannot be removed or retired
- **Where:** `XXFND_PRIVILEGE_PKG.REGISTER_FEATURE_PAGE` (apex/db/09b) only adds a row to XXFND_FEATURE_PAGES; COMMON has
  no routine and no console screen that removes or retires one, and the table has no enabled flag.
- **Effect:** on an upgraded database, XXFND_FEATURE_PAGES keeps the rows of pages KYC has removed: 40, 41, 44, 45, 90,
  91, 98, 100, 172, 10020-10023, 10030-10033, 10050-10052 (release 88), 30-34 (release 89) and 214 (release 91, under
  CASES). Nothing shows them (KYC's menus list only pages it has), but they are stale setup rows KYC cannot clean up
  (no direct writes to COMMON tables).
- **Needed:** an UNREGISTER_FEATURE_PAGE routine (refuses another application's row, like the REGISTER_* routines), or
  a delete on the feature page screen.

## C9 - An application cannot be unregistered, and a registered application cannot be deleted
- **Where:** the REGISTER_* routines (XXFND_PRIVILEGE_PKG, XXFND_VPD_PKG, XXFND_LOOKUP_PKG, XXFND_DFF_PKG, XXFND_ATTACH_PKG,
  XXFND_NOTIFY_PKG, XXFND_WORKFLOW_PKG, XXFND_APPROVAL_RULE_PKG, XXFND_APPROVAL_PKG, XXFND_INTEGRATION_PKG,
  XXFND_ERROR_PKG) only add rows; there is no UNREGISTER_* routine for any of them.
  `XXFND_APPLICATION_PKG.DELETE_APPLICATION` (apex/db/09d) refuses through DELETE_BLOCKER while the application is
  enabled or owns any row in an XXFND_ table with APPLICATION_CODE, or any feature.
- **Effect:**
  - An application cannot retire what it registered (features, privileges, feature pages - see C8 -, lookups and
    values, flexfields, value sets, document entities / categories / attachment pages, templates, task settings,
    processes, approval types / rules, configuration tables, purposes, messages, data rules). Removed KYC items stay as
    stale rows (for example the KYC_RFI attachment page, the KYC_PARAMETER lookup, the page mappings of C8).
  - An application that has registered its setup can never be deleted: every registered row blocks the delete and
    there is no way to remove those rows first. Taking an application out means writing COMMON's tables by hand.
- **Needed:** an UNREGISTER_* routine (or a retire flag) for each REGISTER_* routine, refusing another application's
  rows; and a DELETE_APPLICATION that removes (or offers to remove) the application's own registered rows, still
  refusing when business data refers to them.

## C10 - Applications are granted direct write access on every COMMON table
- **Where:** `XXFND_SHARE_PKG.GRANT_TO` (apex/db/19c) grants each application schema INSERT, UPDATE, DELETE and
  REFERENCES on every XXFND_ table (with SELECT), as well as EXECUTE on the packages.
- **Effect:** an application can change COMMON data with plain SQL, bypassing COMMON's routines (their checks, ownership
  rules and audit). This breaks the golden rule "data changes in COMMON only through COMMON routines". Today one KYC
  script does so: 16l copies the case approval rules from the approval matrix into XXFND_APPROVAL_RULES,
  XXFND_APPROVAL_RULE_STEPS and XXFND_APPROVAL_RULE_CONDS, because COMMON registers only one default rule per type
  (REGISTER_DEFAULT_RULE) and has no routine to register several rules for one type.
- **Needed:** grant applications SELECT (with grant option, for their views) and EXECUTE only - no INSERT, UPDATE or
  DELETE; and a routine to register an application's approval rules (several per type, with steps and conditions), so
  KYC 16l can call it instead of writing the tables. Every data-changing COMMON routine takes the application (code or
  ID) and changes only that application's rows (golden rule, from the user).

## C11 - The grants to applications depend on script order
- **Where:** `XXFND_SHARE_PKG.GRANT_TO_APPLICATIONS` is called in scripts 19c, 24 and 26; scripts 27-30 run after it.
- **Effect:** none today (27-30 create no object), but an object a later script creates is not granted to the
  applications until the next COMMON install or upgrade, so an application using it fails until then.
- **Needed:** call GRANT_TO_APPLICATIONS once, as the last COMMON install and upgrade script.
