# KYC Requests

Feature of KYC Compliance Platform.

## Purpose
Requesting departments ask for KYC on a counterparty.

## Usage
200 lists requests; 201-204 create a request (counterparty, risk screening, party details, review and submit); 205 shows a request; 206 is the approval task page.

## Benefit
One intake that screens risk, avoids duplicate counterparties and routes to approval.


## Release 99 - requester area
- Create Request is 3 steps: Counterparty (201, with the Risk Screening), Party Details (204), Review and Submit (203);
  page 202 is no longer in the wizard.
- Risk Screening (201): the requester questionnaire plus "Business counterparty ownership structure type" (18k);
  Check saves the draft and answers (`SAVE_SCREENING`) and shows the outcome (`SCREENING_OUTCOME`, the same private rule
  `INTAKE_RULE` as `EVALUATE`). Business Relationship Type and Justification only when KYC is required.
- Request form rules: `REQUEST_ERROR` calls `XXCMP_PARTY_PKG.PARTY_ERROR` with `P_REQUEST_FORM = Y` (no registration
  type for an organisation, no email / phone, no stop on a duplicate number).
- A requester (no Cases - View) sees Next Steps on 203 and a History without approvers on 205, no questionnaire regions
  (Global Page regions request-next-steps, request-history-requester). Home: department tiles and Create Request.

## Uses (objects of these features are named in its files)
cases, common:approval-setup, common:attachments, common:data-security, common:information-requests, common:lookups, common:roles-privileges, common:workflow-setup, kyc-rules, parties

## Used by
cases, dashboard, home, kyc-rules, monitoring, parties

## Files
See `repos/kyc/docs/components/kyc-requests/technical.md` (generated on every build): pages, database objects, shared components, configuration and tests.
