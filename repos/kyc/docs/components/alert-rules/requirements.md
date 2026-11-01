# Alert Rules - requirements (KYC)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/kyc/docs/README.md`. Open KYC items are on the "KYC Application" board.

## Alert Rules

- **Purpose:** The rules that raise monitoring alerts on approved counterparties.
- **What it does:** Pages 225 / 226: each rule has a type (review due, review overdue, SLA breach, document expiry, adverse screening), a number of days, an optional risk tier, whether to notify a role and whether to start a review automatically.
- **Why:** Monitoring is configured as data, not code.
