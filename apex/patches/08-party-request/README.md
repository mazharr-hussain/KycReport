# Patch 08 – Party and Request redesign (release 23)

Goes on top of patch 07 (release 22, app ID 134). It builds the agreed designs in `apex/design/party.md` and
`apex/design/request.md`. Party and Request ship together because the database change is shared.

## What changes for users

### Party
- **One party form everywhere.** It is a single region on the Global Page (page 0), used by the Party dialog (24),
  the Party page (21, read only), the new owner / officer (23) and Create Request (201). A change to it is made once.
- **One column per organisation / individual pair.** The label follows the party type:

  | Column | Organisation | Individual |
  |---|---|---|
  | JURISDICTION | Country | Nationality |
  | REGISTRATION_NUMBER | Registration No. | ID Number |
  | ENTITY_TYPE | Entity Type | ID Type |
  | INCORPORATION_DATE | Incorporation Date | Date of Birth |

- **Required fields:**
  - Every party: type, name, and country / nationality.
  - Organisation: registration number and entity type.
  - Individual: ID type, when an ID number is entered.
  - Email or phone.
  - The date can't be in the future.
  - The same number and country as another party is refused.
- **New display-only fields:**
  - **Party Status:** *Pending* when created from a request; then *Approved*, *Rejected* or *Cancelled* with its request. Parties created by Compliance, and all existing parties, are *Approved*.
  - **Next KYC Date:** set when a KYC case is approved, from the risk tier's review months with the PEP cap. It is cleared when the case is rejected.
- **Contact persons:** the old type / value columns are gone. Older rows became contact persons, and their email / phone / website also filled the party's empty main details. There is one primary contact per party.
- **Owners / officers:**
  - Ownership % is required for Shareholder, Beneficial Owner and Parent Company, and must be empty for the other roles.
  - The active owners of a party can't hold more than 100%.
  - A new owner is entered in the common party form.
  - The unused *Officer Corrected* and *Latest UBO Status* columns are gone.
- **Lists:**
  - Parties list: the default report shows Number, Name, Type, Reg./ID No., Country, Email, Phone, Party Status, Next KYC Date, Enabled and Edit. The other columns, including Created / Updated By / On, can be shown under **Actions → Columns**.
  - The party page's Contact Persons and Ownership regions work the same way, with the Created / Updated columns hidden by default.

### Request
- **Step 1 has two parts:**
  - **Request:** Department, **Business Justification (required)**, and the contact person (hidden by the build option *Request - Contact Person*).
  - **Counterparty:** an **existing approved party**, or a **new counterparty** entered in the common party form. A new counterparty is **created as a Pending party** when the request is saved.
- **Possible matches** are only a warning. On the request page, Compliance can **Merge** a duplicate Pending party into an existing party. This replaces the old match decision.
- **Statuses:** *Draft, In Progress, Information Needed, Approved, Rejected, Cancelled*. Older requests were moved: Submitted → In Progress, Completed → Approved.
- **New fields on the list and the request page:**
  - **KYC Required:** Yes when Compliance reviews; No when approved automatically.
  - **Pending With:** the requester, the Compliance user holding the task, or "Compliance".
  - **Action Date:** the last step taken.
- **Workflow:**
  - Submit starts the KYC_REQUEST workflow, as before.
  - *Request Information* on the checklist task sets **Information Needed**. The requester sees the question on the request page and uses **Respond**, which sets the request back to In Progress. The task definition's events do this.
  - *Approve – Open Case* sets the request and its party to **Approved**. *Reject* sets both to **Rejected**.
- **Cancel Request:** the requester can cancel in Draft, In Progress or Information Needed. The workflow ends, and a Pending party that no other request uses is cancelled.
- **Raise RFI is removed** from the request page. Information requests are only part of the workflow.

## Before you run it
The database script **drops columns after moving their data**:
- parties and requests: NATIONALITY, ID_NUMBER, ID_TYPE, DATE_OF_BIRTH
- contacts: CONTACT_TYPE, CONTACT_VALUE
- relationships: OFFICER_CORRECTED_FLAG, LATEST_UBO_STATUS

**Take a backup first**: export the schema, or at least XXCMP_PARTIES, XXCMP_REQUESTS, XXCMP_PARTY_CONTACTS and XXCMP_PARTY_RELATIONSHIPS. For an individual, the nationality replaces the country of residence.

## Deploy from the APEX screens
1. **Back up** as above, and export app 134.
2. **SQL Workshop → SQL Scripts → Upload** `08-db-party-request.sql` → **Run**. At the end:
   - *no rows* invalid objects
   - the three new columns listed: PARTY_STATUS, NEXT_KYC_DATE, LAST_ACTION_DATE

   The script is idempotent, so running it again is safe.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_23.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No** (step 2 did it).
4. **Optional:** to show the request contact person, go to **Shared Components → Build Options → Request - Contact Person** and set Status = **Include**.

`app/` holds the changed application files (pages 0, 20–24, 30, 32, 200, 201, 203, 205, 230; build options; the
Document Checklist Review task definition) and the supporting-object copies of the database scripts.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- `request_party_test.sql` 28/28: request rules, the Pending party, switching to an existing party, submit and the workflow, Information Needed, cancel, reject / approve and the party status.
- `party_test.sql` 21/21: form rules and shared columns, rights, duplicate check, ownership % rules, merge.
- `kyc_flow_test.sql` 23/23: the full flow, including the party's Next KYC Date after case approval.
- Browser tests:
  - `request_party_ui.py` 14/14: create, submit, information needed / respond, approve, list columns, merge, cancel.
  - `party_ui.py` 18/18
  - `request_approval_ui.py` 8/8
  - `kyc_ui.py` 17/17
- The data moves (16f) ran on my database, which had data from earlier releases, and running them again changes nothing.
- `apex validate` passes.

## Known limits
- A requester still sees "available to Compliance" on the party card of their own Pending party. The request page shows the counterparty details typed on the request.
- Requests still waiting on the old *Counterparty Match* task (workflow 1.1) have no match decision screen any more. Compliance can merge from the party page instead.
