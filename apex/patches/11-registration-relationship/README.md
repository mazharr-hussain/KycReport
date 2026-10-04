# Patch 11 – Registration type, business relationship, rejected requests (release 26)

Goes on top of patch 10 (release 25, app ID 134). Items 1–12 of the latest review.

## What changes for users

### Registration Type (party form, everywhere)
- New field **Registration Type**, linked to the number: Commercial Registration, Trade Licence, Tax / VAT Number, Other.
  - For an individual it is the **ID Type**, as before.
  - **Entity Type** is now only an organisation's category (LLC, PJSC…). It is hidden for individuals.
- **Order:**
  - Organisation: Entity Type → Name → Country → **Registration Type → Registration No.**
  - Individual: Name → Nationality → **ID Type → ID Number**
- **Required:**
  - Registration Type for an organisation.
  - ID Type when an ID Number is entered.
- **Existing data:** an individual's ID type moves from ENTITY_TYPE to REGISTRATION_TYPE. Mandatory document rules keep working, because they match an individual on the ID type.

### Business Relationship (request level)
- New required field on Create Request step 1: **Customer, Vendor / Supplier, Partner, Agent / Intermediary, Other**. You can extend the list in Lookups (BUSINESS_RELATIONSHIP).
- **One per request:** a party that is both customer and vendor gets one request for each.
- **Where it shows:** Requests list (column), review, request view and approval screen.
- **It goes on to the case:** Cases list column. Reviews raised from a case keep it.
- **Request Approval Paths (166)** have a new criterion, Business Relationship. For example, vendors can follow a Procurement path.
- **Parties** show **Business Relationships** (in the party details and on the Parties list), derived from the party's requests with their latest status. Nothing new is stored on the party.

### Requests
- **Rejected requests can be edited and resubmitted:**
  - **Edit** on the list sends the request back to Draft and its party back to Pending.
  - The history keeps the rejection.
  - Cancel is allowed too.
- **Approval screen:**
  - Reject on the left; Request Information and Approve on the right.
  - Same layout at the top and the bottom.
- **Request Information** is no longer offered when the approver is also the requester. That case caused `APEX.TASK.REQUEST_INFO_NOT_AUTHORIZED`, because APEX sends the question to the requester.
- **Approval History** stays in time order: what happened, then Pending, then Waiting.
- **Party number:** it is no longer a link on the request screens, because everything is already on the screen. The link stays on the case pages.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `11-db-registration-relationship.sql` → **Run**. At the end:
   - *no rows* invalid objects
   - the 5 new columns listed

   The script is idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_26.zip` → **Replace Existing Application** 134 → **Install Supporting Objects: No**.

`app/` holds the changed pages (0, 20, 21, 23, 24, 166, 200, 201, 203, 205, 206, 210) and the supporting objects.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- **DB tests:**
  - `request_party_test.sql` 48/48, which includes these new checks:
    - registration type and business relationship required
    - a rejected request edited back to Draft, with its party Pending
    - the case carries the relationship
    - APEX refuses Request Information to oneself, and `can_request_info` hides it
  - `party_test.sql` 21/21, which includes an individual's ID type in REGISTRATION_TYPE
  - `kyc_flow_test.sql` 23/23
- **Browser tests:**
  - `request_party_ui.py` 24/24, which includes these new checks:
    - no party link on the review
    - history order
    - the relationship shown
    - the approval button bar
  - `party_ui.py` 22/22, which includes the field order for both types
  - `kyc_ui.py` 18/18
- `apex validate` passes.

## Notes
- Requests from before this release have no business relationship. They show empty. A rejected or draft one asks for it when it is submitted again.
- *REQ-000001* in your environment looks stuck: In Progress, KYC Required "-", Pending With "System". It is probably from before release 23. **Withdraw** then **Cancel** cleans it up.
