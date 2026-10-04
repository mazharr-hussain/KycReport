# Patch 16 – sticky record header, party uniqueness, party card (release 31)

Goes on top of patch 15 (release 30, app ID 134).

## What changes for users
- **Request, approval and case screens:** the header card (number, status badges, requester) and the left section
  menu stay in place while the page scrolls; jumping to a section stops below the header.
- **Party uniqueness:** a new party is a duplicate only when another active party has the same **registration / ID
  type, number and country** (number compared without spaces and punctuation). The same number and country with
  another type is allowed. The message now reads *Party P-… already has this registration type, registration no. and
  country: use that party.* Older parties without a type still count as duplicates.
- **Party card:** the relationship badges (e.g. *Partner · In Progress*) are removed.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `16-db-party-unique.sql` → **Run**. At the end: *no rows* invalid
   objects. Idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_31.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.

`app/` holds the changed files: `kyc-app.css`, `kyc-app.js`, supporting objects 16e.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `xxcmp_party_pkg` compiles, no invalid objects. `exact_party_number` on P-000033 (passport): same type → P-000033,
  other type → none, no type given → P-000033.
- Request view 205 scrolled 900px and to the end: header card and section menu stay below the title bar (screenshots).
- `apex validate` passes.
