# Framework (COMMON)

The base every COMMON component and every application runs on. No feature, no page: database only.

## Purpose
Install and upgrade safety (checked DDL steps, release tracking), the who / audit columns, errors and messages, shared
utilities, the sharing of COMMON objects with the application schemas, and the final recompile.

## Usage
- `00a-prerequisites-check.sql` - first script of every install and upgrade of every application: checks the privileges.
- `00-deployment-framework.sql` - `XXFND_DDL_PKG` (CREATE_TABLE, ADD_COLUMN, ADD_CONSTRAINT, ENSURE_INDEX, ... , RELEASE_APPLIED,
  MARK_RELEASE) and `XXFND_SCHEMA_RELEASES`, `XXFND_DROPPED_OBJECTS`: runs in each schema (COMMON and every application).
- `07-who-and-audit-triggers.sql`, `19-reporting-views-and-recompile.sql` - run for every application.
- `objects/`: `XXFND_UTIL_PKG` (install mode, current user, language), `XXFND_ERROR_PKG` / `XXFND_MESSAGES` (messages and
  error handling), `XXFND_SCHEMA_PKG` (who triggers, policies), `XXFND_UI_PKG` (status colours), `XXFND_SHARE_PKG` (grants
  to the application schemas, COMMON seed).

## Benefit
No install error (no ORA-00955): every database gets exactly what it is missing and a re-run does nothing.

## Depends on
-

## Installation requirements
Runs first; 00a lists the grants the schema needs when one is missing.

## Roles and privileges
None (database only). `XXFND_SHARE_PKG.GRANT_TO` gives application schemas SELECT and EXECUTE (and today
also INSERT / UPDATE / DELETE: COMMON issue C10) on the COMMON objects.

## How another application uses it
Its install runs 00a, 00, 07 and 19 from here (no copy) and uses `XXFND_DDL_PKG` for every change to its own objects;
it reaches the shared packages through grants and synonyms (KYC script 03). `XXFND_DDL_PKG` and `XXFND_SCHEMA_RELEASES` are
local to each schema (never granted).
