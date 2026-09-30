# Patch 02 – Request module issues

This patch goes on top of patch 01 (release 16). It changes only the request module.

## What changes
| # | Issue (from *Request Module issues*) | Change |
|---|---|---|
| 1 | Requesting department | The department defaults from the employee profile (`XXFND_EMPLOYEES.DEPARTMENT_NAME`, matched to the Requesting Department lookup by code or name). Requesters cannot change it, on screen or in the database. Compliance staff (privilege Cases – View: Officer, Manager, Head) can choose any department. If a profile has no department, the requester chooses one. |
| 2 | New party details | **Contact Person, Contact Email and Contact Phone are required** for a new counterparty. Registration number, entity type, date of incorporation, country, date of birth, nationality and identity document are optional. When the party is created, the contacts are added to the party (Email as primary, Phone). |
| 3 | Matching | **Same registration number (or identity document number) and same country = 100%.** Such a counterparty is refused even if *None of the listed parties* is switched on: the requester must use the existing party. Other similar parties (same number but another country = 90%, similar name, date or country) still need the confirmation switch. The matches table now shows **Party, Registration No, Name, Country, Match %, Registration Match %, Why, Action** on page 201 and on the request page (205). |
| 4 | Mandatory documents | **Submit is refused until the mandatory documents are attached.** These are the documents required by the Mandatory Document Rules for the entity type and/or country. The message names the missing documents. They can be attached on step 3 (Review and Submit); for an existing party, documents already on the party count. |
| 5 | Workflow | Submit starts the `KYC_REQUEST` workflow, as before. **The merge decision is now part of the workflow's document checklist review task** (workflow version 1.2): Compliance opens the checklist task, and on the request page decides *Merge into this party* or *Confirm as New Party*, then approves the checklist in the same task. There is no separate Counterparty Match task any more. Versions 1.0 and 1.1 stay for requests started on them. |

Monitoring reviews (periodic or event-driven) are not affected by 2 and 4: they come with their existing party.

## Files
| File | Where it goes |
|---|---|
| `02-db-request-module.sql` | SQL Workshop → SQL Scripts (or SQLcl) as the parsing schema |
| `app/pages/p00201-create-request.apx`, `app/pages/p00205-kyc-request.apx` | `apex/src/database/xxcus/apex_apps/f101/pages/` |
| `app/shared-components/workflows/KYC-REQUEST.apx` | `.../f101/shared-components/workflows/` |
| `app/supporting-objects/{install,upgrade}-scripts/16b-kyc-requests-cases.sql` | `.../f101/supporting-objects/...` (same database change, for future installs) |

## Deploy from the APEX screens
1. **SQL Workshop → SQL Scripts → Upload** `02-db-request-module.sql` → **Run**. The last results must show both
   packages **VALID** and the columns `CONTACT_EMAIL`, `CONTACT_NAME` and `CONTACT_PHONE`.
2. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_17.zip`, choosing **Replace Existing Application** with
   the same ID. Answer **No** to *Install Supporting Objects*, because step 1 did it. Export the current application
   first if you want a backup.
3. Check in **SQL Commands**:
   `select workflow_version, state from apex_appl_workflow_versions where application_id = <app id> and workflow_static_id = 'KYC_REQUEST';`
   → 1.2 Active, 1.0 and 1.1 Inactive.
4. Put each requester's department in their employee profile (Administration → Employees and Access), unless it
   comes from Fusion.

## Deploy with SQLcl
`@02-db-request-module.sql`, then copy `app/` over the source and run `apex import -input apex/src/database/xxcus/apex_apps/f101 -id <app id>`.

## Tested (local Oracle 26ai + APEX 26.1)
- `request_party_test.sql` 27/27 (exact block, 90% other country, registration match %, contacts required and copied
  to the party, department from the profile, mandatory documents at submit, match decided inside the checklist task).
- `kyc_flow_test.sql` 22/22.
- Browser: `request_party_ui.py` 21/21 and `kyc_ui.py` 17/17.
- `monitoring_test.sql` 19/20. The one failure is test data, not code: the check needs a fourth approved party with no review in progress.
