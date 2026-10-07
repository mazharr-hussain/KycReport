# Patch 29 – upgrade order fix for the party package (release 44)

Goes on top of any earlier release of app 134.

## What was wrong
Importing release 43 with *Install Supporting Objects: Yes* showed compile errors in script **16b**:
`PLS-00306: wrong number or types of arguments in call to 'PUT_PARTY'` (xxcmp_request_pkg) and
`PLS-00302: component 'OWNERSHIP_TREE_JSON' must be declared` (xxcmp_case_pkg). 16b ran before 16e, which
defines the new party package (`p_address`, `ownership_tree_json`), so 16b compiled against the old one.

## Fix
The `XXCMP_PARTY_PKG` specification is now its own script **16e0** (upgrade 124 / install 164), before 16b;
16e keeps the body. No other change.

## Deploy – application import only
**App Builder → Import** `KYC-Compliance-Platform-APEXlang_44.zip` → **Replace Existing Application** 134 →
**Install Supporting Objects: Yes**. (If you already imported 43 with the errors, this import fixes them; the final
recompile script had already made the packages valid, but the errors in the log are now gone.)

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- Reproduced: release 39 party package + current 16b → the same PLS-00306 / PLS-00302.
- Fixed: from that state, all 35 upgrade scripts in APEX order → no errors, no invalid objects.
