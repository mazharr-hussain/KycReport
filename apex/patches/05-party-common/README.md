# Patch 05 – Common party card and party dialog

Goes on top of patch 04 (release 19). It adds one shared "Party" card and one shared party editor.
When a party field changes, it now changes in one place for every screen.

## What changes
- **Party card** (same card everywhere): party number (a link to the Party page), name, type, registration
  number or identity document, entity type or date of birth / nationality, country, main email / phone / website,
  the primary contact person and the status (Active / Disabled / Merged into …).
  It is shown on:
  - **KYC Request (205)**, once the request is linked to a party;
  - **Case (211)**;
  - **Case Decision (212)**;
  - **Reassessment (222)**.

  The card follows data security: a requester, who cannot see the party master, sees
  *"The party details are available to Compliance."*
- **Party dialog (new page 24)** is the one place to create or change a party's details: identity (now including
  the identity document for individuals), main contact details and additional information. It opens from:
  - **Parties → Create Party**: after Create you land on the new party;
  - **Party page → Edit → Edit Details** (the Party page itself is always read only now);
  - **Edit Party** on the card on the request (205) and case (211) pages, for Parties – Manage. The card refreshes after Save.
- Page 24 belongs to the Parties feature, so the same privileges apply: View to open it, Create to create, Manage to save.
- Contact persons, ownership and documents are still added on the Party page in Edit mode. The new owner / officer
  option (page 23) uses the same database rules (`XXCMP_PARTY_PKG.CREATE_PARTY`).

## Deploy from the APEX screens
1. **SQL Workshop → SQL Scripts → Upload** `05-db-party-common.sql` → **Run**. The results must show
   `XXCMP_PARTY_PKG` **VALID** and page 24 under the `PARTIES` feature.
2. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_20.zip`, choosing **Replace Existing Application**
   (same ID). Answer **No** to *Install Supporting Objects*.

## Tested (local)
- `party_ui.py` 15/15: create in the dialog, edit details through the dialog, contact person, new owner, merge.
- `request_approval_ui.py` 8/8: the card for the requester and for Compliance, and Edit Party from the request page.
- `kyc_ui.py` 17/17 (case pages) and `monitoring_ui.py` 14/14.
- `apex validate` passes.
