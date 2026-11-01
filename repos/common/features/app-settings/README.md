# Application Settings

COMMON component, module Platform (feature `APP_SETTINGS`).

## Purpose
Application settings.

## Usage
Pages 10022 / 10023 list and change the APEX application settings of the running application.

## Benefit
Settings are changed from the console, not in App Builder.

## Depends on (objects of these components are named in its files)
applications, roles-privileges

## Used by (COMMON components)
optional-features

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 10022 Application Settings (`pages/p10022-application-settings.apx`)
- 10023 Application Setting (`pages/p10023-application-setting.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- packages: `XXFND_APP_SETTING_PKG`

## Roles and privileges
Privileges `APP_SETTINGS.<action>` for VIEW, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

An application declares its settings in its own application.apx (appSetting). COMMON issue C7: the screen changes the settings of the running application only.

### Public routines
- `XXFND_APP_SETTING_PKG`: SET_FEATURE_STATUS, SET_VALUE

## Tests
- in `../../tests/` (whole application)

## Files
See `repos/common/docs/components/app-settings/technical.md` (generated on every build): pages, database objects, shared components, configuration and tests.
