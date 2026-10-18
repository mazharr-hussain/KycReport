# Patch 103 - COMMON 90: My Tasks opens every application's task, Data Model installs from App Builder

Build: `COMMON-Application-APEXlang_90.zip` (application version "Release 90"). COMMON only; KYC is not changed.

## What changes (two fixes, nothing else)
1. **My Tasks opens another application's task page (COMMON issue C12).**
   - **Before:** the task link was used as APEX gives it (`f?p=134:206:...:P206_TASK_ID:...`), with no checksum.
     KYC's task pages (206 approval, 211 case) require a checksum, so they answered "Session state protection
     violation".
   - **Now:** page 40 opens `apex_util.prepare_url(details_link_target)`, the same link with its checksum (as KYC Home
     does).
2. **Data Model (script 33) installs from App Builder.**
   - **Before:** in App Builder > Install Supporting Objects, script 33 failed with ORA-20002 "You are not allowed to
     do this." when it set COMMON's object prefix. `XXFND_DATA_MODEL_PKG.APP_VISIBLE` read the APEX session directly
     (`v('APP_USER')`), and during the install that session is App Builder's. So it refused, although the script runs
     in install mode.
   - **Now:** `APP_VISIBLE` uses `XXFND_UTIL_PKG.IN_APEX_SESSION`, the same rule as the Manage check. In install mode,
     or without an APEX session, it allows; on COMMON's pages nothing changes.

## Files
- `db/33-data-model.sql`: `APP_VISIBLE` (one line). The script can be re-run safely and changes only what is missing.
- `app/pages/p00040-my-tasks.apx`: the link column of the My Tasks report.
- `app/application.apx`: Release 90.
- `tests/r90_my_tasks_ui.py` (new, browser): opens each kind of task from COMMON My Tasks.

## Deploy
1. App Builder > Import `COMMON-Application-APEXlang_90.zip` over COMMON (135), Install Supporting Objects: Yes. Use
   Parsing Schema XXFUSION if XXCUS has `APEX_ADMINISTRATOR_READ_ROLE` (patch 102); otherwise import as XXCUS, switch
   the parsing schema to XXFUSION and run Install Supporting Objects.
2. If COMMON 89 failed in script 33 on your server, this upgrade completes it: it registers the Data Model feature,
   its pages and privileges, COMMON's prefix, the table groups and the menu entries.

## Tests (local database, COMMON 90 with KYC 92/93)
- Data Model:
  - Before the fix, `APP_VISIBLE('COMMON')` in install mode, in an APEX session of another application, returned N
    (the cause).
  - After the fix it returns Y in install mode and still N on a normal page of another application.
  - The real path: App Builder import of COMMON 90 with Install Supporting Objects, with COMMON's prefix row deleted
    first. The install completed, the prefix row was created again and the DATA_MODEL feature is registered.
  - `r89_data_model_test.sql`: 22 pass, 0 fail (without the dictionary grants).
- My Tasks (`r90_my_tasks_ui.py`):
  - OFFICER1: the KYC Document Checklist Review (206) and Case Investigation (211) tasks open from COMMON My Tasks, and
    their links carry a checksum. COMMON's Information Request tasks still open: 4/4 pass.
  - REQ1: the link is accepted, and the case page then refuses REQ1 by its own privilege check (a requester has no
    case privilege), as it should: 2/2 pass.
- Nothing else in COMMON was changed or re-tested.
