# Integrations

COMMON component, module Integrations (feature `INTEGRATIONS`).

## Purpose
Endpoints, purposes and the transmission log.

## Usage
Pages 120 / 121 (servers), 122 / 123 (integration purposes), 124 / 125 (transmission log, a call).

## Benefit
Every outbound call is logged and can be retried; servers and credentials are set up once.

## Depends on (objects of these components are named in its files)
applications, attachments, audit-log, change-approvals, lookups, roles-privileges

## Used by (COMMON components)
applications, attachments, change-approvals, flexfields, lookups, notifications, users-access

## Installation requirements
COMMON (application 135) is installed in schema XXFUSION in the install order of `db/manifest.json` (prerequisites check 00a first; 00b stops an install in the wrong schema). APEX web credentials and remote servers of the workspace; Fusion HCM sync needs FUSION_BASE_URL and its credential.

## Application objects
### Pages
- 120 Servers (`pages/p00120-servers.apx`)
- 121 Server (`pages/p00121-server.apx`)
- 122 Integration Purposes (`pages/p00122-integration-purposes.apx`)
- 123 Integration Purpose (`pages/p00123-integration-purpose.apx`)
- 124 Transmission Log (`pages/p00124-transmission-log.apx`)
- 125 Call (`pages/p00125-call.apx`)

### Shared components
- `shared-components/lovs.apx`

## Database objects (schema XXFUSION)
- tables: `XXFND_INTEGRATION_CALLS`, `XXFND_INTEGRATION_ENDPOINTS`, `XXFND_INTEGRATION_PURPOSES`, `XXFND_INT_ENDPOINTS`, `XXFND_SERVERS`, `XXFND_TRANSMISSIONS`
- views: `XXFND_INTEGRATION_CHANGES_V`, `XXFND_SERVERS_V`
- packages: `XXFND_INTEGRATION_PKG`
- triggers: `XXFND_INT_PURPOSES_MC`

## Roles and privileges
Privileges `INTEGRATIONS.<action>` for VIEW, CREATE, MANAGE (VIEW opens its pages, CREATE adds, MANAGE changes and deletes); a page opens with the privilege on the feature it is mapped to.
Roles at install: Common Administrator (COMMON_ADMIN) holds every privilege of an admin feature (19c); other roles get them from the COMMON console.

## How another application uses it
1. The application is onboarded (Applications, or its own install with the generic script 00c-onboard-with-common.sql). 2. Its schema gets the grants (SELECT, REFERENCES, EXECUTE - no INSERT, UPDATE or DELETE) and creates synonyms for the COMMON objects (script 00c does both). 3. It registers its rows through the COMMON REGISTER_* routines and changes COMMON data only through COMMON routines (golden rule; no direct SQL). 4. It links to COMMON pages with link type "page in a different application" (`app: COMMON`, same session). 5. Its users get the privileges through roles in the COMMON console.

The application registers its purposes with `XXFND_INTEGRATION_PKG.REGISTER_PURPOSE` (KYC: 18h) and calls a service with `CALL` (logged, retried with `RETRY`).

### Public routines
- `XXFND_INTEGRATION_PKG`: CALL, CAN_RETRY, DELETE_PURPOSE, DELETE_SERVER, LOG_END, LOG_START, REGISTER_PURPOSE, RETRY, SAVE_PURPOSE, SAVE_SERVER, SERVER, SYNC_FROM_FUSION, SYNC_HCM, SYNC_RUNNING, SYNC_USER_NAMES, TEST_CONNECTION, UNREGISTER_APPLICATION, UNREGISTER_PURPOSE, UPSERT_FUSION_WORKER (registration: REGISTER_PURPOSE)

## Tests
- in `../../tests/` (whole application)

## Files
- `db/packages/xxfnd_integration_pkg.sql`
- `db/tables/xxfnd_int_endpoints.sql`
- `db/tables/xxfnd_integration_calls.sql`
- `db/tables/xxfnd_integration_endpoints.sql`
- `db/tables/xxfnd_integration_purposes.sql`
- `db/tables/xxfnd_servers.sql`
- `db/tables/xxfnd_transmissions.sql`
- `db/triggers/xxfnd_int_purposes_mc.sql`
- `db/views/xxfnd_integration_changes_v.sql`
- `db/views/xxfnd_servers_v.sql`
- `pages/p00120-servers.apx`
- `pages/p00121-server.apx`
- `pages/p00122-integration-purposes.apx`
- `pages/p00123-integration-purpose.apx`
- `pages/p00124-transmission-log.apx`
- `pages/p00125-call.apx`
- `shared-components/lovs.apx`
