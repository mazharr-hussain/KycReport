# Monitoring - requirements (KYC)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/kyc/docs/README.md`. Open KYC items are on the "KYC Application" board.

## Monitoring

- **Purpose:** Ongoing monitoring of approved counterparties.
- **What it does:** 220 watchlist (next review dates), 221 alerts, 222 early reassessment; a daily job starts periodic reviews and raises alerts.
- **Why:** Reviews and risks are tracked after onboarding without manual follow-up.
