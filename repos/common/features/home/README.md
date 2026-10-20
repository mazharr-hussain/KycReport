# Common Home

COMMON component, module Platform (feature `COMMON_HOME`).

## Purpose
The landing page of the COMMON application.

## Usage
Opened after sign-in to COMMON (page 1); a start point to the setup screens a user may open.

## Benefit
One entry point for IT and delegated administrators.

## Depends on (objects of these components are named in its files)
notifications, users-access, workflow-setup

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 1 Home (`pages/p00001-home.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- none of its own (it uses the objects of the components above)

## Roles and privileges
Privileges `COMMON_HOME.<action>` for VIEW (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_HOME.VIEW, seed_common in 19c).

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Not used by other applications.

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
- `pages/p00001-home.apx`
