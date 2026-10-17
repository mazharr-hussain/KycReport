# monitoring

Feature of KYC Compliance Platform. Copied as it is from the current application (no change).

## Uses (objects of these features are named in its files)
alert-rules, cases, common:attachments, common:data-security, common:lookups, common:notifications, common:roles-privileges, common:workflow-setup, kyc-requests, parties

## Used by
alert-rules, dashboard, parties

## Files
- `db/packages/xxcmp_monitor_pkg.sql`
- `db/tables/xxcmp_alerts.sql`
- `db/views/xxcmp_watchlist_v.sql`
- `pages/p00220-monitoring-watchlist.apx`
- `pages/p00221-alerts.apx`
- `pages/p00222-reassessment.apx`
- `shared-components/automations/kyc-monitoring.apx`
- `tests/monitoring_test.sql`
- `tests/monitoring_ui.py`
