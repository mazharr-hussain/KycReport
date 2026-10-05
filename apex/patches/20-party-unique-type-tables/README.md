# Patch 20 – party uniqueness by type, Possible Matches type, contact / owner tables (release 35)

Goes on top of patch 19 (release 34, app ID 134).

## What changes for users
- **Duplicate party check:** *Party P-… already has this registration type, registration no. and country* now only
  appears when all three match. A party with another registration / ID type, or none recorded, does not block
  (it still shows under Possible Matches).
- **Possible Matches:** new column **Registration / ID Type**.
- **Contact Persons** and **Owners and Officers** (request, approval, party and case screens) are tables like Party
  Documents: Name, Job Title, Email, Phone / Party, Role, Relationship, Ownership %, Start Date, End Date. The Action
  column (Edit) shows only where the lists can be edited.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `20-db-party-unique-type.sql` → **Run**. At the end: *no rows* invalid
   objects. Idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_35.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.

`app/` holds the changed files: Global Page (0), supporting objects 16b, 16e.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `exact_party_number`: same type → the party; other type → none; existing party without a type and a new one
  with a type → none.
- Possible Matches shows the type column; Contact Persons shows Name / Job Title / Email / Phone with Action on
  Party Details (204) only.
- `request_party_ui.py` 24/24, `party_ui.py` 22/22; `apex validate` passes; no invalid objects.
