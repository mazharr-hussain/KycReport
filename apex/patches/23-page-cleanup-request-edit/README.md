# Patch 23 – page cleanup and Edit on the request view (release 38)

Goes on top of patch 22 (release 37, app ID 134).

## What changes
- **Edit on the KYC Request view (205):** an **Edit** button at the top right opens the request wizard (201). It
  shows for the requester while the request is Draft, Information Needed or Rejected (same rule as Edit on the KYC
  Requests list).
- **Pages removed** (not reachable from any menu, list or task):
  - 42 Task Details: only a breadcrumb entry pointed to it; tasks open 206 (request approval), 211 (case), 31 / 172.
  - 212 Case Decision: unlinked since release 27 (decisions are taken on the case screen 211).
  Their feature-page rows are deleted. The app now has 101 pages.

## Deploy
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `23-db-page-cleanup.sql` → **Run**. At the end: *no rows* invalid objects.
   Idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_38.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**. Make the SSO scheme current again if you use it.

`app/` holds the changed files: page 205, breadcrumbs, supporting objects 18b / 18d. Pages 42 and 212 are deleted
(Replace Existing Application removes them).

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `apex validate` passes; DB script clean, no invalid objects; no feature-page rows left for 42 / 212.
- Browser: Draft request as the requester shows Edit at the top right and opens 201 with the request; an approved
  request shows no Edit (4/4). `kyc_ui.py` 26/26, `request_party_ui.py` 24/24.
