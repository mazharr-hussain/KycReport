# Patch 03 – Party issues (+ Oracle Database Accounts authentication)

Goes on top of patch 02 (release 17). It changes the Party feature (pages 20–23) and adds the authentication scheme.

## What changes
| # | Issue (from *Party issues*) | Change |
|---|---|---|
| 1 | Parties list: no Edit | **Edit** link on each row, for Compliance (Parties – Manage) and only for enabled parties. The party number still opens the party. |
| 2 | Party page: view has edit functions | The party **opens read only**: no Save, no Enabled switch, no Add Contact / Owner / Attachment buttons, and no edit links on the rows. **Raise RFI is removed.** An **Edit** button (Parties – Manage) switches to edit mode, where Save, Cancel, the Add buttons and the row Edit links appear. After Save the party shows read only again. Create Party opens directly in edit mode. |
| 2 | Merging | **Possible Existing Matches** has *Merge into this party* for Compliance. It merges the party you are on (the duplicate) into the matched one. Its requests, cases (including closed ones), screenings, alerts, case notes, beneficial-owner decisions, contact persons, ownership and documents move to the kept party. The kept party's empty details are completed from the duplicate. The duplicate is disabled, remembers which party it was merged into, and can't be edited or merged again. You then land on the kept party. |
| 3 | Owner / officer: only existing parties | **Owner / Officer Is: An existing party / A new party.** For a new one, enter the type (individual or organisation), name and country, plus the registration number (organisation) or date of birth (individual). It's created as a party and linked in one step. This needs Parties – Create, and a new organisation with the same registration number and country as an existing party is refused. |
| 4 | Contact = person; main details at party level | **Email, Phone, Website and Fax are now on the party** (Party Details). **Contacts are now Contact Persons:** name (required), job title, email and phone, with at least one of email or phone, plus primary and enabled. Existing email / phone / website contact rows fill the party's empty main details once, and still show in the contact list. |
| – | Authentication | **Oracle Database Accounts** is added and is now the application's current scheme. Oracle APEX Accounts stays available. |

Other features adjusted only because they use party contacts:
- **RFI to an external party** now picks a contact person's email (page 32 and the email sent).
- **A new party created from a request** gets the request's email and phone as its main details, and the request contact as its primary contact person.

## Important: Oracle Database Accounts
Users now sign in with a **database user name and password**. The application's roles are still granted by user name in Administration → Employees and Access, so each person needs:
1. a database account with the same user name (for example `REQ1`), and
2. their roles in the application, as today.

APEX workspace users that have no database account can no longer sign in. To switch back, set the application's current authentication to *Oracle APEX Accounts* (Shared Components → Authentication Schemes).

## Files
| File | Where it goes |
|---|---|
| `03-db-party.sql` | SQL Workshop → SQL Scripts (or SQLcl), as the parsing schema |
| `app/pages/p00020…p00023`, `p00032…` | `apex/src/database/xxcus/apex_apps/f101/pages/` |
| `app/shared-components/authentications.apx`, `app/application.apx` | same paths under `f101/` |
| `app/supporting-objects/...` | `f101/supporting-objects/` (the same database changes, for future installs and upgrades) |

## Deploy from the APEX screens
1. **SQL Workshop → SQL Scripts → Upload** `03-db-party.sql` → **Run**. The last results must show every package and the trigger **VALID**, plus the new columns.
2. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_18.zip`, choosing **Replace Existing Application** with the same ID. Answer **No** to *Install Supporting Objects*, because step 1 did it. Export the current application first as a backup.
3. Make sure your database users exist before you sign out (see above).

## Tested (local Oracle 26ai + APEX 26.1)
- `party_test.sql` 14/14 (create party rights and duplicate check, main contact details, merge with a closed case, contacts, relationships, completed details).
- `party_ui.py` 14/14 (Edit link, read-only view, edit and save, contact person drawer, new owner, merge from the matches).
- Request module: `request_party_test.sql` 27/27 and `request_party_ui.py` 21/21.
- `apex validate` passes.
- The browser tests ran with Oracle APEX Accounts, because my local test users aren't database accounts. The new authentication scheme passed validation but wasn't tried in a sign-in.
