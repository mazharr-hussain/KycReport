# Cases - requirements (KYC)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/kyc/docs/README.md`. Open KYC items are on the "KYC Application" board.

## Cases

- **Purpose:** The KYC investigation of a counterparty, from opening to approval.
- **What it does:** 210 lists cases; 211 is the case screen (summary, party, ownership tree, screening, documents, risk, notes and RFIs, review and submit); 213 screening, 215 document verification, 216 create a case, 217 compliance report, 218 source of funds, 219 FIU report. Approval levels follow the Approval Setup.
- **Why:** One guided investigation with the evidence, risk decision and approvals in one place.
