# Give Feedback

COMMON component, module Platform (feature `GIVE_FEEDBACK`).

## Purpose
Everyone gives feedback on the page they are on, in any application.

## Usage
Page 173, opened from an application's navigation bar (with P173_APPLICATION_ID and P173_PAGE_ID).

## Benefit
One feedback form for all applications.

## Depends on (objects of these components are named in its files)
applications

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 173 Give Feedback (`pages/p00173-give-feedback.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- none of its own (it uses the objects of the components above)

## Roles and privileges
Privileges `GIVE_FEEDBACK.<action>` for VIEW, CREATE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Every role, at install (27).

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Link to COMMON page 173 (`app: COMMON`) passing &APP_ID. and &APP_PAGE_ID. (or the entry Give Feedback of `XXFND_APP_MENU_V`); every signed-in user opens it (release 87).

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
