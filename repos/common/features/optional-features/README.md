# Optional Features

COMMON component, module Platform (feature `OPTIONAL_FEATURES`).

## Purpose
Optional features of each application, switched on or off.

## Usage
Pages 10020 / 10021 include or exclude an application's build options named "Feature - ...".

## Benefit
Parts of an application are switched on or off without a new release.

## Depends on (objects of these components are named in its files)
app-settings, applications

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 10020 Optional Features (`pages/p10020-optional-features.apx`)
- 10021 Optional Feature (`pages/p10021-optional-feature.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- none of its own (it uses the objects of the components above)

## Roles and privileges
Privileges `OPTIONAL_FEATURES.<action>` for VIEW, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications). 2. Its schema gets the grants and creates synonyms for the COMMON objects (as KYC script 03 does). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

An application defines build options named "Feature - <name>"; `XXFND_APP_SETTING_PKG.SET_FEATURE_STATUS` switches them.

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
- `pages/p10020-optional-features.apx`
- `pages/p10021-optional-feature.apx`
