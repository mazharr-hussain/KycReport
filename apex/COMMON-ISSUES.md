# COMMON issues found by KYC (for the COMMON team)

KYC does not change COMMON. Each issue below was found while adapting KYC to COMMON 86. Until COMMON fixes it, KYC keeps its
own copy of what it needs (from the user: "anything linked to common will be reported to common team, and we will
duplicate anything in our module").

| # | Issue | Where | Effect | KYC until fixed |
|---|-------|-------|--------|-----------------|
| C1 | Business users cannot open COMMON. The application authorization APP_USER lets only IT (Common Administrator) and delegated administrators in (rule since COMMON 71). | XXFND_USER_PKG.AUTHORIZED('APP_USER'), f135 authorization app-user | A requester or officer who follows a link to COMMON's shared user pages (My Tasks 40, E-mail 46, Information Request 143, Feedback 173) gets "You do not have access to this application". | KYC keeps its own My Tasks, information request, e-mail and feedback screens. |
| C2 | A cancelled configuration change leaves its CONFIG_CHANGE workflow faulted, and the change cannot be submitted again. | XXFND_APPROVAL_PKG / CONFIG_CHANGE workflow | The same change is blocked until the faulted workflow is removed by hand. | none (reported) |
| C3 | Script 17 rewrites KYC's lookups on every COMMON upgrade. | apex/db/17 | An administrator's change to a KYC lookup is lost after a COMMON upgrade. | KYC registers its lookups in 18h (keeps administrator changes). |
| C4 | DELEGATED_URL points to KYC page 98, which KYC no longer has. | XXFND_APPLICATION_PKG.DELEGATED_URL | The "managed in the application" link of a delegated function opens "page not found". | none (reported) |
| C5 | Information Request page 143 has no documents region; information requests have no due dates or task settings. | f135 page 143, XXFND_RFI_PKG | Documents asked for in an RFI cannot be attached or seen there; no deadline reminders. | KYC keeps its own RFI screens. |
| C6 | The E-mail page 46 has no list of the party's contacts. | f135 page 46 | The sender types the address by hand. | KYC keeps its own e-mail screen. |
| C7 | The Application Settings screen changes the settings of the running application only (XXFND_APP_SETTING_PKG.SET_VALUE refuses another application). | XXFND_APP_SETTING_PKG | A KYC setting (for example CASE_SLA_DAYS, PEP_REVIEW_MONTHS, REVIEW_LEAD_DAYS) cannot be changed from COMMON's console. | Changed in App Builder (Shared Components > Application Settings). |
