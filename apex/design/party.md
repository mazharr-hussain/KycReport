# Party – agreed design

Status: **built in release 23 (patch 08)**; release 24 (patch 09): read-only fields hidden when creating / editing, Possible Matches with a confirmation on every create / edit (21, 23, 24, 201), one-click Edit on 21 with Save and buttons at the top and bottom.

## General rules
- **One party form everywhere, defined once.** The party form is a single region on the **Global Page (page 0)**,
  shown only on the pages that need it: Party dialog (24), Create Request step 1 (201) and Owner / Officer (23).
  A change to the region is made once. The validation is one database function used by all of them.
- **Request → party:** a new counterparty is **created as a party on the fly** when the request is saved, with
  Party Status *Pending*. The requester can edit it while the request is Draft or Information Needed, but not once the
  request is closed, or when the request uses an existing party. Possible duplicates are shown as a warning. Compliance
  can merge a duplicate later.
- **Type-driven fields:** one column per pair; the label changes with the party type.
- **Required fields are never hidden** on a create / edit form. Search and list tables may hide any column by default;
  users can show it again (Actions → Columns).
- **Who columns** (Created By / On, Updated By / On) are hidden by default on every screen, but available to show.
  The contacts and owners regions become Interactive Reports so this is possible.
- **No RFI on the Party or Request screens.** An RFI is only part of a workflow step, for example
  *Request Information* in the approval task. The Party page already has no RFI. The Request page (205) loses its
  **Raise RFI** button, which goes into the Request design. The Case page (211) also has Raise RFI; it stays until
  Cases is reviewed.

## A. Party (`XXCMP_PARTIES`)
| # | Field (Organisation / Individual) | Column | Rule |
|---|---|---|---|
| 1 | Party Number | PARTY_NUMBER | automatic, read only |
| 2 | Party Type | PARTY_TYPE | **required** (Organisation / Individual) |
| 3 | Name | PARTY_NAME | **required** |
| 4 | Country / Nationality | JURISDICTION | **required** |
| 5 | Registration No. / ID Number | REGISTRATION_NUMBER | **required** for an organisation, optional for an individual; same number + country = duplicate |
| 6 | Entity Type / ID Type | ENTITY_TYPE | **required** for an organisation; for an individual, required when an ID Number is entered |
| 7 | Incorporation Date / Date of Birth | INCORPORATION_DATE | optional |
| 8 | Email | EMAIL | email **or** phone required |
| 9 | Phone | PHONE | email **or** phone required |
| 10 | Website | WEBSITE | optional |
| 11 | Fax | FAX | optional |
| 12 | Data Provenance | DATA_PROVENANCE | Compliance only |
| 13 | Last Verified | LAST_VERIFIED_DATE | Compliance only |
| 14 | Enabled | ENABLED_FLAG | default Yes, Compliance only |
| 13a | Party Status | **PARTY_STATUS** (new) | **display only**: *Pending* (created from a request, not yet approved) → *Approved* when Compliance approves the request, or the request is approved automatically (KYC Required = No). Also *Rejected* when the request is rejected, and *Cancelled* when the request is cancelled (only if no other request uses the party). A party created by Compliance on page 20 is *Approved*. Existing parties are set to *Approved*. |
| 14a | Next KYC Date | **NEXT_KYC_DATE** (new, DATE) | **display only**, set automatically when a KYC case is approved: approval date + review months of the risk tier (Lookup RISK_TIER, tag), capped at PEP_REVIEW_MONTHS for a PEP. Cleared when the party's KYC is rejected. The periodic review uses it. |
| 15 | Merged Into / Merge Note | MERGED_INTO_PARTY_ID, MERGE_NOTE | set by merge, read only |
| 16 | Additional Information | ATTRIBUTE_CATEGORY, ATTRIBUTE1… (DFF) | as configured in Flexfields |
| 17 | Who columns | CREATED_BY … OBJECT_VERSION_NUMBER | automatic, hidden by default |

**Merged columns (agreed names: keep the existing organisation column):**
| Column kept | Organisation label | Individual label | Dropped (data moved first, individuals only) |
|---|---|---|---|
| JURISDICTION | Country | Nationality | NATIONALITY (an individual's nationality wins over country) |
| REGISTRATION_NUMBER | Registration No. | ID Number | ID_NUMBER |
| ENTITY_TYPE | Entity Type (lookup ENTITY_TYPE) | ID Type (lookup ID_TYPE) | ID_TYPE |
| INCORPORATION_DATE | Incorporation Date | Date of Birth | DATE_OF_BIRTH |

Side effects:
- Duplicate check: number + country for both types. For individuals, name + date of birth also stays.
- Mandatory document rules (Country + Entity Type): for an individual, they now match on **Nationality + ID Type**.
- The party check constraint XXCMP_PARTIES_CK4 is no longer needed and is dropped.

The 4 pairs become 4 columns, with existing data moved into them. The same change applies to `XXCMP_REQUESTS` (the
request's counterparty), duplicate matching, the party card and the party check constraint.

## B. Contact Persons (`XXCMP_PARTY_CONTACTS`, page 22)
| # | Field | Column | Rule |
|---|---|---|---|
| C3 | Name | CONTACT_NAME | **required** |
| C4 | Job Title | JOB_TITLE | optional |
| C5 | Email | EMAIL | email **or** phone required |
| C6 | Phone | PHONE | email **or** phone required |
| C7 | Primary | PRIMARY_FLAG | one primary per party |
| C8 | Enabled | ENABLED_FLAG | disable instead of delete |
| C11 | Additional Information | DFF | as configured |
| – | Who columns | … | hidden by default |
- **Dropped:** CONTACT_TYPE, CONTACT_VALUE. The old rows (from before release 18) move first: email / phone / website go
  onto the party, and a named contact becomes a contact person.

## C. Owners / Officers (`XXCMP_PARTY_RELATIONSHIPS`, page 23)
| # | Field | Column | Rule |
|---|---|---|---|
| R2 | Party (object) | OBJECT_PARTY_ID | the party you are on |
| R3 | Owner / Officer (subject) | SUBJECT_PARTY_ID | **required**; an existing party, or a new one through the **common party form** |
| R4 | Relationship Type | RELATIONSHIP_TYPE | **required**; the current list, maintained in Lookups (page 101) |
| R5 | Ownership % | OWNERSHIP_PERCENTAGE | **required** for Shareholder, Beneficial Owner and Parent Company, blank for other types; active owners' total ≤ 100% |
| R6 | Start Date | START_DATE | **required**, default today |
| R7 | End Date | END_DATE | optional; an ended row stays as history |
| R10 | Additional Information | DFF | as configured |
| R11 | Who columns | … | hidden by default |
- **Dropped:** OFFICER_CORRECTED_FLAG, LATEST_UBO_STATUS.
- The same person with two roles is recorded as two rows. Circular ownership stays blocked.

## D. Parties list (page 20)
Shown: Number (link), Name, Type, Registration No. / ID Number, Country, Email, Phone, Party Status, Next KYC Date, Enabled, Edit.
Hidden, available: Entity Type / ID Type, Date, Primary Contact, Provenance, Last Verified, Merged Into, Who columns.

## Open before build
None. Next: agree the Request screens, then build Party and Request as one patch each.
