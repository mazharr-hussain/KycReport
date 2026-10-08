# Patch 57 – the applications follow IT's function switches (release 72: COMMON and KYC)

## What changes
- **A function switched off for an application disappears from it** (COMMON > Administration > Applications >
  the application > Common Functions):
  - Attachments: KYC's document regions (party, request, RFI, case) are hidden and nothing can be attached.
  - Flexfields: no flexfield fields are shown, validated or saved.
  - Notifications: no e-mail is sent.
  Everything is switched on for KYC, so nothing changes until IT switches something off.
- **KYC's Administration shows only KYC's own setup screens** (KYC rules, mandatory documents, approval matrix and
  paths, alert rules, workflow monitor, settings, usage). The shared setup is IT's, in COMMON (IT only); KYC no
  longer links into COMMON.

## Database
- COMMON: new 09d (the switches' table and XXFND_APP_FUNCTION_PKG, moved earlier from 21b); 11, 14, 15 ask
  XXFND_APP_FUNCTION_PKG.IS_ENABLED. 21b only seeds the switches.
- COMMON 16i: XXFND_ADMIN_SCOPE_PKG.LOCAL_PAGE (used by the KYC menus).
- KYC: no database change (its install creates the synonyms to the new objects).

## Deploy (in this order)
1. COMMON: import `COMMON-Application-APEXlang_72.zip` over COMMON (import as XXCUS, Parsing Schema XXFUSION),
   Install Supporting Objects: Yes.
2. KYC: import `KYC-Compliance-Platform-APEXlang_72.zip` over app 134 (Replace), Install Supporting Objects: Yes.
