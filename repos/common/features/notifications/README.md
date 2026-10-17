# Notifications

COMMON component, module Workflow (feature `NOTIFICATIONS`).

## Purpose
E-mail and in-app notification templates.

## Usage
Pages 109 / 110 (templates), 116 (delivery rules: e-mail, in-app, push), 117 (log).

## Benefit
Notifications are templates and rules (data), sent the same way for every application.

## Depends on (objects of these components are named in its files)
applications, attachments, communications, data-security, information-requests, integrations, roles-privileges, users-access, workflow-setup

## Used by (COMMON components)
applications, change-approvals, communications, information-requests, lookups, my-tasks, roles-privileges, workflow-setup

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). APEX e-mail (SMTP) for e-mail; settings MAIL_FROM and MAIL_FOOTER of COMMON.

## Application objects
### Pages
- 109 Notification Templates (`pages/p00109-notification-templates.apx`)
- 110 Notification Template (`pages/p00110-notification-template.apx`)
- 116 Notification Delivery (`pages/p00116-notification-delivery.apx`)
- 117 Notification Log (`pages/p00117-notification-log.apx`)

### Shared components
-

## Database objects (schema XXFUSION)
- tables: `XXFND_NOTIFICATION_TEMPLATES`, `XXFND_NOTIFY_CHANNELS`
- packages: `XXFND_NOTIFY_PKG`

## Roles and privileges
Privileges `NOTIFICATIONS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its templates with `XXFND_NOTIFY_PKG.REGISTER_TEMPLATE` (KYC: KYC_ALERT) and sends with `SEND`, `SEND_TO_USERS` or `RAISE_EVENT`.

### Public routines
- `XXFND_NOTIFY_PKG`: COMMON_SETTING, CONTACTS, DELIVER_EMAIL, DELIVER_FUSION, DELIVER_IN_APP, DELIVER_PUSH, EMAIL_ERROR, EVENT_FOR, HAS_PUSH, MARK_ALL_READ, MARK_READ, PREVIEW_MESSAGE, PREVIEW_SUBJECT, RAISE_EVENT, RECORD_OPEN, RECORD_RECEIVED, RECORD_SENT, REGISTER_CONTACT_SOURCE, REGISTER_TEMPLATE, RULE_RECIPIENTS, SEND, SEND_EMAIL, SEND_MESSAGE, SEND_TEST, SEND_TO_USERS, SET_RULE_ENABLED, UNREAD_COUNT, UNREGISTER_APPLICATION, UNREGISTER_CONTACT_SOURCE, UNREGISTER_TEMPLATE, USER_LANGUAGE (registration: REGISTER_CONTACT_SOURCE, REGISTER_TEMPLATE)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_notify_pkg.sql`
- `db/tables/xxfnd_notification_templates.sql`
- `db/tables/xxfnd_notify_channels.sql`
- `pages/p00109-notification-templates.apx`
- `pages/p00110-notification-template.apx`
- `pages/p00116-notification-delivery.apx`
- `pages/p00117-notification-log.apx`
