# Application Menu

COMMON component, module Reference Data (feature `APPLICATION_MENU`).

## Purpose
The navigation (side menu, top bar) of every application in one place, and every page with who uses it.

## Usage
Page 169: all pages of every application (privilege, In Menus Of, Linked From, Opened From); 167 / 168: the menu of one application.

## Benefit
One place to manage every navigation; entries are shown by the privileges of the pages they open.

## Depends on (objects of these components are named in its files)
applications, roles-privileges

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema).

## Application objects
### Pages
- 167 Application Menu (`pages/p00167-application-menu.apx`)
- 168 Menu Entry (`pages/p00168-menu-entry.apx`)
- 169 All Pages (`pages/p00169-all-pages.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- none of its own (it uses the objects of the components above)

## Roles and privileges
Privileges `APPLICATION_MENU.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its entries with `XXFND_APPLICATION_PKG.REGISTER_MENU_ENTRY` (P_MENU_CODE SIDE or TOP_BAR) and subscribes to COMMON's Navigation Menu and Navigation Bar lists (`XXFND_NAV_PKG.NAV_MENU`).

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
See `repos/common/docs/components/application-menu/technical.md` (generated on every build): pages, database objects, shared components, configuration and tests.
