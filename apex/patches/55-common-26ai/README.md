# Patch 55 – COMMON compatible with 26ai (release 70: COMMON only)

## What changes
- COMMON's compatibility mode is 26.1 (was 24.2): the application runs with the APEX 26.1 behaviours.
- Checked: COMMON uses no deprecated or desupported APEX component or API (no legacy items, no `APEX_UTIL`
  string/table or print-document calls, no `G_Fnn` arrays, no `HTMLDB_` / `WWV_FLOW` internals) and its database code
  uses nothing desupported in Oracle AI Database 26ai (no `DBMS_JOB`, `WM_CONCAT`, `LONG` columns, `UTL_FILE`).
- KYC is not changed (it stays on 24.2 until it is changed on purpose).

## Deploy
COMMON: import `COMMON-Application-APEXlang_70.zip` over COMMON (import as XXCUS, Parsing Schema XXFUSION - see
`apex/install/COMMON/INSTALL.md`), Install Supporting Objects: Yes. No database change in this release.
