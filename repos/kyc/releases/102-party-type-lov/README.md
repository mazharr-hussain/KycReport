# KYC 102 - Create Request: Party Type list error

Build: `releases/KYC-Compliance-Platform-APEXlang_102.zip` (application version "Release 102"), on top of KYC 101.
Checked with the APEXlang validation ("Validation successful"). No database change.

## Fix
Create Request (page 201) failed to render the Party Type radio group (`P0_PARTY_TYPE`, Global Page): its list of
values query started with a `--` comment, so APEX ran it as a "PL/SQL function body returning a SQL query" and failed.
The query now starts with `SELECT` (the comment moved inside it). Same values: Legal Person / Natural Person (Individual)
on page 201, the lookup meanings elsewhere.

## Files
- `app/pages/p00000-global-page.apx`

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_102.zip` over KYC (134). No database steps.

## Live check
As TKYC_REQ1: Create Request opens with the Party Type choices Legal Person / Natural Person (Individual).
