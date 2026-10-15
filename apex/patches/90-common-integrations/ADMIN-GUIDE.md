# COMMON - Administrator guide

## How to change a server

Since release 83 the servers COMMON calls are **APEX Remote Servers**, and their secrets **APEX Web Credentials**, of
the workspace. The COMMON Servers screen (Integrations > Servers) shows them with their health; it does not change
them. The **workspace administrator** changes them:

| Server (static ID) | What it is | Web Credential |
| --- | --- | --- |
| FUSION | Oracle Fusion Cloud (HCM workers for the user sync) | FUSION_CREDENTIALS (user and password) |
| UCM_MAIN | Oracle WebCenter Content (document store) | XXFND_UCM_CRED (user and password) |
| SHAREPOINT_MAIN | Microsoft SharePoint through Microsoft Graph (document store) | XXFND_GRAPH_CRED (client ID and secret) |
| OUTLOOK_GRAPH | Outlook through Microsoft Graph (planned) | XXFND_GRAPH_CRED |

1. Sign in to the workspace as a workspace administrator.
2. **Change the URL:** App Builder > Workspace Utilities > Remote Servers > the server > Endpoint URL > Apply Changes.
3. **Change the secret:** App Builder > Workspace Utilities > Web Credentials > the credential > enter the user and
   password (or the client ID and client secret) > Apply Changes. Secrets are never stored in the application or in
   the database tables.
4. In COMMON, open Integrations > Servers > the server and press **Test Connection**. The result is kept and shown in
   the Servers list (Last Test).
5. Only the static ID ties a server to COMMON: do not change it.

When the application is installed in a new workspace, the servers are created with placeholder URLs
(e.g. https://your-fusion-host.oraclecloud.com) and the Web Credentials without secrets: set them as above before the
first call. Nothing calls a server that is not set up (the Fusion HCM sync waits; the document stores stay on the
database store until a storage rule points to them).

## Fusion HCM sync

The automation **Fusion HCM sync** of COMMON (Shared Components > Automations) is installed **disabled**. Once the
FUSION server and FUSION_CREDENTIALS are set up and Test Connection is reachable, switch it on. It runs daily through
purpose HCM_SYNC (REST Data Source FUSION_HCM_WORKERS) and refreshes the Fusion employees; workers no longer returned
are disabled, not deleted.

## Retrying a failed call

Integrations > Transmission Log lists every request (APEX web service log). A failed call made through the COMMON call
procedure opens its detail with a **Retry** button (Integrations - Manage). Calls made directly by a page are shown
but not retried: repeat the action on that page.
