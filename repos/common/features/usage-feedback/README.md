# Usage and Feedback

COMMON component, module Platform (feature `USAGE_FEEDBACK`).

## Purpose
The feedback people gave on every registered application, and its follow-up.

## Usage
Pages 171 / 172: IT reads and follows up feedback.

## Benefit
Feedback from every application in one place.

## Depends on (objects of these components are named in its files)
applications

## Used by (COMMON components)
-

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). APEX feedback of the workspace.

## Application objects
### Pages
- 171 Feedback (`pages/p00171-feedback.apx`)
- 172 Feedback Follow-up (`pages/p00172-feedback-follow-up.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- none of its own (it uses the objects of the components above)

## Roles and privileges
Privileges `USAGE_FEEDBACK.<action>` for VIEW, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (27).

## How another application uses it
1. The application is onboarded (Applications). 2. Its schema gets the grants and creates synonyms for the COMMON objects (as KYC script 03 does). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application links its Feedback entry to COMMON page 173 (Give Feedback).

### Public routines
-

## Tests
- in `../../tests/` (whole application)

## Files
- `pages/p00171-feedback.apx`
- `pages/p00172-feedback-follow-up.apx`
