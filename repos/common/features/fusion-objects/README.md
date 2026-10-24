# Fusion Objects

COMMON component, module Integrations (feature `FUSION_OBJECTS`, release 107).

## Purpose
A metadata-driven engine to onboard Oracle Fusion BICC view objects and Fusion REST resources in a few clicks, always
from live metadata of the Fusion pod, through the one Fusion server and credential of the workspace.

## Usage
- 190 Fusion Objects: the onboarded objects, their mode, status, business view and last sync.
- 191 Onboard Object: find the object in the catalog (Harvest BICC, Harvest REST, Add REST Resource), select attributes
  and children, choose mode / schedule / Object Storage, Activate.
- 192 Object Detail: attributes, versions, drift, runs; Run Now, Check Metadata, Pause, Resume, Retire.
- 193 Drift Queue: breaking metadata changes waiting for an administrator (Approve / Reject).
- 194 Run Log: every BICC extract and load, REST pull and metadata check.

Applications read a replica only through its business view `XXFI_<code>_V` (versioned views `XXFI_<code>_V<n>`) and
use real-time / push through `XXFND_FI_RUN_PKG.FETCH_ROWS` / `PUSH`. No inline queries on Fusion in pages.

## How it works
- Harvester `XXFND_FI_META_PKG`: BICC Meta Data REST API (`/biacm/rest/meta`: offerings, datastores, columns with
  `includeCustomization=true`) and Fusion REST `describe`, into the catalog `XXFND_FI_CATALOG`.
- Registry `XXFND_FI_REGISTRY_PKG`: objects, attributes, children (`XXFND_FI_OBJECTS`, `_ATTRIBUTES`, `_CHILDREN`).
- Generators `XXFND_FI_GEN_PKG`: replica and staging tables, versioned business views (`XXFND_FI_VERSIONS`), BICC
  datastore configuration (PUT) and the object's BICC job, REST query template.
- Runtime `XXFND_FI_RUN_PKG` (automation "Fusion Objects run", every 15 minutes, installed disabled): BICC job started
  and polled from APEX, extract files read from Object Storage with DBMS_CLOUD, unzipped (APEX_ZIP), parsed
  (APEX_DATA_PARSER), merged; deletes from the primary-key extract; REST paged pulls (incremental by the last-update
  attribute). Runs in `XXFND_FI_RUNS`.
- Governance `XXFND_FI_DRIFT_PKG`: daily metadata check; non-breaking drift applied, breaking drift to the Drift Queue
  (`XXFND_FI_DRIFT`); alerts (template `XXFND_FI_ALERT`) to the holders of FUSION_OBJECTS - Manage.
- Every Fusion call goes through `XXFND_INTEGRATION_PKG.CALL` (purpose `FUSION_OBJECTS`, REST Data Source `FUSION_ROOT`):
  logged on the Transmission Log and retryable.

## Depends on
integrations (server, purpose, CALL, call log), roles-privileges, notifications, workflow-setup (users with a
privilege), applications (COMMON menu).

## Installation requirements
- The Fusion server and credential of the workspace (Fusion integration prerequisite); the Fusion user behind the
  credential needs BICC access (BI Applications administration duty) for BICC objects.
- BICC replica: an OBJECT_STORAGE server on the Servers screen (region, namespace; its credential static ID is the
  DBMS_CLOUD credential name, created in XXFUSION with `DBMS_CLOUD.CREATE_CREDENTIAL`), a bucket, and that bucket
  registered as BICC external storage; XXFUSION needs EXECUTE on DBMS_CLOUD (called through dynamic SQL).
- Switch on the automation "Fusion Objects run" once the above is set up.

## Application objects
### Pages
- 190 Fusion Objects (`pages/p00190-fusion-objects.apx`)
- 191 Onboard Object (`pages/p00191-onboard-object.apx`)
- 192 Object Detail (`pages/p00192-object-detail.apx`)
- 193 Drift Queue (`pages/p00193-drift-queue.apx`)
- 194 Run Log (`pages/p00194-run-log.apx`)
### Shared components
- Automation Fusion Objects run (`shared-components/automations/fusion-objects-run.apx`)
- REST Data Source FUSION_ROOT (`app/shared-components/rest-data-sources/fusion-root.apx`)
### Database objects
- Tables: `db/tables/xxfnd_fi_*.sql`; packages: `db/packages/xxfnd_fi_*_pkg.sql`; setup: `db/scripts/40z-fusion-objects-setup.sql`
