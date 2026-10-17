# Platform Activity

COMMON component, module Platform (feature `PLATFORM_ACTIVITY`).

## Purpose
Page views, top users, errors and page performance of every registered application (APEX activity log).

## Usage
Page 170, for IT.

## Benefit
One activity view for all applications instead of one report set per application.

## Depends on (objects of these components are named in its files)
applications

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). The APEX activity log of the workspace.

## Application objects
### Pages
- 170 Platform Activity (`pages/p00170-platform-activity.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- none of its own (it uses the objects of the components above)

## Roles and privileges
Privileges `PLATFORM_ACTIVITY.<action>` for VIEW, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (27).

## How another application uses it
1. The application is onboarded (Applications). 2. Its schema gets the grants and creates synonyms for the COMMON objects (as KYC script 03 does). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

Nothing to do: every registered application appears.

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
- `pages/p00170-platform-activity.apx`
