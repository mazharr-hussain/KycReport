# Patch 25 – party address (release 40)

Goes on top of patch 24 (release 39, app ID 134).

## What changes
- **Party:** new field **Headquarters Address** (organisation) / **Address** (individual) on the common party form:
  Create / Edit Party, new owner / officer, and the counterparty step of Create Request. It shows on the party card
  (Party region of the party, request and case screens). When Compliance merges a duplicate party, an empty address is
  completed from the duplicate. Optional.
- DB: column `XXCMP_PARTIES.ADDRESS varchar2(1000)`; `xxcmp_party_pkg.put_party` / `save_party` and
  `xxcmp_request_pkg.save_request` take `p_address` (default null); `load_items` sets `P0_PARTY_ADDRESS`; `card_html`
  and `field_label('ADDRESS')`.

## Deploy
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `25-db-party-address.sql` → **Run**. At the end: *no rows* invalid objects.
   Idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_40.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**. Make the SSO scheme current again if you use it.

`app/` holds the changed files: pages 0, 23, 24, 201; supporting objects 16b, 16d, 16e.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- DB script clean, no invalid objects; `apex validate` passes.
- `party_ui.py` 23/23 (label *Headquarters Address* for an organisation, address saved with the party);
  party card shows it; `request_party_ui.py` 24/24.
