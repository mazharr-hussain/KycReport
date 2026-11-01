# Alert Rules

Feature of KYC Compliance Platform. Copied as it is from the current application (no change).

## Purpose
The rules that raise monitoring alerts on approved counterparties.

## Usage
Pages 225 / 226: each rule has a type (review due, review overdue, SLA breach, document expiry, adverse screening), a number of days, an optional risk tier, whether to notify a role and whether to start a review automatically.

## Benefit
Monitoring is configured as data, not code.


## Uses (objects of these features are named in its files)
common:lookups, common:roles-privileges, monitoring

## Used by
dashboard, monitoring

## Files
See `repos/kyc/docs/components/alert-rules/technical.md` (generated on every build): pages, database objects, shared components, configuration and tests.
