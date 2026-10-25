# Monitoring

Feature of KYC Compliance Platform. Copied as it is from the current application (no change).

## Purpose
Ongoing monitoring of approved counterparties.

## Usage
220 watchlist (next review dates), 221 alerts, 222 early reassessment; a daily job starts periodic reviews and raises alerts.

## Benefit
Reviews and risks are tracked after onboarding without manual follow-up.


## Uses (objects of these features are named in its files)
alert-rules, cases, common:attachments, common:data-security, common:lookups, common:notifications, common:roles-privileges, common:workflow-setup, kyc-requests, parties

## Used by
alert-rules, dashboard, parties

## Files
See `docs/TECHNICAL.md` (generated on every build): pages, database objects, shared components, configuration and tests.
