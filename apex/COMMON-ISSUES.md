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
