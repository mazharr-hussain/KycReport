# Kyc Requests - requirements (KYC)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/kyc/docs/README.md`. Open KYC items are on the "KYC Application" board.

## Kyc Requests

- **Purpose:** Requesting departments ask for KYC on a counterparty.
- **What it does:** 200 lists requests; 201-204 create a request (counterparty, risk screening, party details, review and submit); 205 shows a request; 206 is the approval task page.
- **Why:** One intake that screens risk, avoids duplicate counterparties and routes to approval.

## KYC 105 - request stages
- **Stages:** Draft > Submitted > Under Review > In Approval > Approved; also Information Needed, KYC Not Required (closed), Rejected, Cancelled. The request is the parent of the case: the case's progress updates the request stage.
- **Create Request:** 201 request (Requesting Department, Requesting Country, Business Relationship, Business Justification - optional) and party, in two columns, no duplicate check; 204 the screening questions on one page; 203 review (request, party, answers, documents - mandatory) and submit; on submit a popup says KYC is required (submitted for the KYC report) or not required (closed).
- **New Requests (200) and Assign (206):** L1 sees the new requests and assigns one or many to a contributor, which opens the case; Approve / Add Approver are hidden.
- **Header card:** the requester sees KYC Required / Not Required; the score only for case viewers.

## KYC 107 - cancel after submit
- **Who and when:** the requester can cancel their own request from submission until it is decided: Draft, Submitted, Under Review, In Approval, Information Needed (Rejected as before). An Approved request, one whose case was approved or rejected, and a request already Cancelled cannot be cancelled.
- **Where:** KYC Requests (200) shows a Cancel action on the requester's own Submitted, Under Review or In Approval requests (Draft and Information Needed cancel on the edit screen, as before), with a confirmation.
- **What happens:** the request's workflow and tasks end; its open case (investigation, pending approval or pending information) is cancelled with its workflow and approval (`XXCMP_CASE_PKG.CANCEL_CASE`) and the request follows its case to Cancelled; a Pending party only this request uses is Cancelled.

