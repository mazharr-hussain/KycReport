# Patch 119 - KYC 96: requesting department by ID (COMMON departments)

Build: `KYC-Compliance-Platform-APEXlang_96.zip` (application version "Release 96"). Install COMMON 102
(patch 118) first - script 03 stops with ORA-20904 otherwise.

## What changes
- `XXCMP_REQUESTS.REQUESTING_DEPARTMENT_ID` and `XXCMP_CASES.REQUESTING_DEPARTMENT_ID` (number) with foreign keys
  `XXCMP_REQUESTS_FK_DEPT` / `XXCMP_CASES_FK_DEPT` to `XXFUSION.XXHR_ORGANIZATIONS (ORGANIZATION_ID)` (departments,
  COMMON). REFERENCES comes from COMMON's grants (19c); without it the keys are skipped with a message and come
  with a re-run.
- Existing rows get the ID of the department with their code (or name); a code COMMON does not have yet becomes a
  department through COMMON's routine (`XXFND_VPD_PKG.SAVE_ORGANIZATION`, application KYC). Closed cases too (the
  lock trigger is off during this one-time fill only). The old code columns stay, read-only.
- Create Request (201) lists COMMON's departments (allowed by data security) and saves the ID; Requests (200), the
  request card (global page) and the request summary show the department name; a new case copies the ID.
- Data security: KYC Requests and KYC Cases are data objects on the department ID (value type ID).
- Approval rules still name the department by its code (attribute REQUESTING_DEPARTMENT, from the ID).
- `XXHR_EMPLOYEES` in the request and case packages, the case page (211) and the LOVs; synonyms from script 03.

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_96.zip` over KYC (134), Install Supporting Objects: Yes
(upgrade).

## Tests
APEXlang validation of the application (offline). Not run on a database, as agreed.
