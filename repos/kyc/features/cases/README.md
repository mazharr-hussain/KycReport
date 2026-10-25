# Cases

Feature of KYC Compliance Platform. Copied as it is from the current application (no change).

## Purpose
The KYC investigation of a counterparty, from opening to approval.

## Usage
210 lists cases; 211 is the case screen (summary, party, ownership tree, screening, documents, risk, notes and RFIs, review and submit); 213 screening, 215 document verification, 216 create a case, 217 compliance report, 218 source of funds, 219 FIU report. Approval levels follow the Approval Setup.

## Benefit
One guided investigation with the evidence, risk decision and approvals in one place.


## Uses (objects of these features are named in its files)
common:applications, common:approval-setup, common:attachments, common:communications, common:data-security, common:information-requests, common:lookups, common:roles-privileges, common:users-access, common:workflow-setup, kyc-requests, kyc-rules, parties

## Used by
dashboard, home, kyc-requests, kyc-rules, monitoring, parties

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
