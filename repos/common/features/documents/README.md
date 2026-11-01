# Documents

COMMON component, module Documents and Records (feature `DOCUMENTS`).

## Purpose
The documents of a record of any application: add, view, replace (the application's attachment page registration says who may change them).

## Usage
Pages 47 (Attachments of a record) and 48 (Document), opened from the application with the record's entity and key.

## Benefit
Applications need no document screens of their own.

## Depends on (objects of these components are named in its files)
attachments

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 47 Attachments (`pages/p00047-attachments.apx`)
- 48 Document (`pages/p00048-document.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- none of its own (it uses the objects of the components above)

## Roles and privileges
Privileges `DOCUMENTS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Every role, at install (27).

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Link to COMMON page 47 (`app: COMMON`) with P47_APP_ALIAS, the source page, region, entity and key (KYC: pages 0 and 211). Every signed-in user opens it (release 87) and sees only the records they may see.

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
See `repos/common/docs/components/documents/technical.md` (generated on every build): pages, database objects, shared components, configuration and tests.
