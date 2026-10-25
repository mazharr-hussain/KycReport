# Communications

COMMON component, module Workflow (feature `COMMUNICATIONS`).

## Purpose
The e-mails with outside people of a record of any application: send, record a received one, history.

## Usage
Page 45 (history of a record) and 46 (E-mail), opened from the application.

## Benefit
One e-mail history for every record, with its files, without e-mail screens in the application.

## Depends on (objects of these components are named in its files)
notifications

## Used by (COMMON components)
lookups, notifications, roles-privileges, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). APEX e-mail (SMTP).

## Application objects
### Pages
- 45 Communications (`pages/p00045-communications.apx`)
- 46 E-mail (`pages/p00046-e-mail.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- tables: `XXFND_COMMUNICATIONS`

## Roles and privileges
Privileges `COMMUNICATIONS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Every role: VIEW and CREATE; MANAGE (record a received e-mail): the roles that manage the notifications (26).

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Link to COMMON page 46 (`app: COMMON`) for the record (KYC: page 211); `XXFND_NOTIFY_PKG.RECORD_SENT` / `RECORD_RECEIVED` store them (only for the application's own records). Every signed-in user opens the pages (release 87). The record's contacts are offered as recipients when the application registers a contact source (`REGISTER_CONTACT_SOURCE`: a view of its schema with PK1_VALUE, CONTACT_NAME, EMAIL_ADDRESS, SELECT granted to COMMON).

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
