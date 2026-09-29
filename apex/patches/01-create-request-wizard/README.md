# Patch 01 - Create Request wizard, steps 1-2 (pages 201, 202)

## What changes
- **Page 201, Counterparty:** no empty choice in Counterparty Type. Organization shows Registration Number and
  Entity Type; Person shows Date of Birth (not in the future) and Nationality. Country is required for both.
  Fields that do not apply are cleared on save. Changing the type of a draft replaces its questionnaire.
- **Page 202, Questionnaire:** the grid is replaced by a question-and-answer form grouped by section, editable at
  once. Next checks the required questions; Previous saves without checking.
- **Starter sections** for the Organization/Person questions, only where an administrator has not set one.

## Files
| File | Where it goes |
|---|---|
| `01-db-xxcmp_request_pkg.sql` | run in SQLcl as the parsing schema (package + section seed) |
| `p00201-create-request.apx`, `p00202-create-request-questionnaire.apx` | `pages/` of the application source |
| `kyc-app.js` | `shared-components/static-files/js/` (adds `kycQuestionnaire`) |
| `diag-request-workflow.sql` | not part of the patch: shows why a submitted request stays "Processing" |

## Deploy
1. `@01-db-xxcmp_request_pkg.sql` - both package rows must be VALID.
2. Copy the three application files into the release 15 source and import it:
   `apex import -input <source folder> -id <app id>`
