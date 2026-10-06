# Patch 27 – ownership tree and screening per party (release 42)

Goes on top of patch 26 (release 41, app ID 134).

## What changes
- **Owners and Officers** (party, request and case screens) shows the **whole ownership tree**: the owners / officers
  of the party, their owners (e.g. holding company → its beneficial owners), and so on (up to 6 levels, indented),
  then the parties this party holds an interest in. New columns: Country / Nationality, Incorporation / Birth Date,
  Registration / ID No., **Document Expiry** (latest expiry date of the party's documents).
- **Case → Party:** the first row is the case's party; every row shows that party's latest screening in the case:
  **Results, Conclusion, Source, Risk Level**. Actions: **Screen** (opens the Screening dialog for that party, or its
  latest screening to change it), **Add Owner** on a related company (Compliance: add the holding's owners from the
  case), **Edit** on the party's own owners.
- **Screening dialog:** new **Risk Level**; *Notes* is now **Conclusion**; shows which party is screened when it is not
  the case's party. The Screenings list shows the risk level and conclusion.
- Fixed: after adding an owner from the case, the Edit links disappeared until the page was reloaded.

DB: column `XXCMP_SCREENINGS.RISK_TIER varchar2(30)` (lookup RISK_TIER); `xxcmp_party_pkg.owners_json` takes
`p_case_id` and returns the tree. App: Global Page item `P0_CASE_ID` (set by the case screen), page 213 item
`P213_SCREEN_PARTY_ID`.

## Deploy
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `27-db-ownership-tree.sql` → **Run**. At the end: *no rows* invalid objects.
   Idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_42.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**. Make the SSO scheme current again if you use it.

`app/` holds the changed pages 0, 211, 213 and supporting objects 16b, 16e.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- DB script clean, no invalid objects; `apex validate` passes.
- Browser: case party ← holding company (60 %) ← beneficial owner shown as a 3-row indented tree; *Screen* on the
  owner opens the dialog for that owner, the saved result / conclusion / source / risk show on its row; *Screen* again
  opens that screening to change it; links stay after the refresh.
- `kyc_ui.py` 26/26, `party_ui.py` 23/23, `request_party_ui.py` 24/24.
