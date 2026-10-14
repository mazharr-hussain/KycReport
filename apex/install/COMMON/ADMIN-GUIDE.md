# COMMON - Administrator guide

## How to change a server

Since release 83 the servers COMMON calls are **APEX Remote Servers**, and their secrets **APEX Web Credentials**, of
the workspace. Since release 86 the COMMON Servers screen (Integrations > Servers) is the register of these servers:
the COMMON administrator adds a server there (its Remote Server, Web Credential and type with the type's details) and
sees its health. The URL and the secret stay with the **workspace administrator**:

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
database until an application's storage points to them).

## Fusion HCM sync

The automation **Fusion HCM sync** of COMMON (Shared Components > Automations) is installed **disabled**. Once the
FUSION server and FUSION_CREDENTIALS are set up and Test Connection is reachable, switch it on. It runs daily through
purpose HCM_SYNC (REST Data Source FUSION_HCM_WORKERS) and refreshes the Fusion employees; workers no longer returned
are disabled, not deleted.

## Retrying a failed call

Integrations > Transmission Log lists every request (APEX web service log). A failed call made through the COMMON call
procedure opens its detail with a **Retry** button (Integrations - Manage). Calls made directly by a page are shown
but not retried: repeat the action on that page.

## Notifications (release 84)

Workflow notifications are set up on **Workflow > Notification Delivery**, nothing is written into the application:

- **Channels:** In the application (the bell and the Notifications list), E-mail, Push notification, Fusion
  notifications. Switch a channel off to send nothing on it.
- **Events:** what happens (a task is assigned, approved, rejected, information requested or submitted, a reminder, an
  escalation, an RFI raised or answered), its wording (a Notification Template, English and Arabic) and the page its
  link opens.
- **Rules:** per event, and optionally per application and process: who is told (the task's owners, the initiator, the
  users of a role or a privilege, the people of the record, the escalation role, the RFI's people) on which channel.
- The **Notification Log** shows every notification and what happened to it (sent, skipped with the reason, failed).

**E-mail:** set the COMMON settings MAIL_FROM (the sender; empty = no e-mail) and MAIL_FOOTER on Application Settings.
The e-mail switches of the Process Catalogue still apply.

**Push:** COMMON is a progressive web app. Each person turns push on for each browser or phone on Notifications >
Push Notifications on This Device. In a new workspace the install makes the push key pair; to make a new one later
(subscriptions are lost): App Builder > COMMON > Edit Application Definition > Progressive Web App > Generate
Credentials.

**Fusion notifications (prepared):** give integration purpose FUSION_NOTIFY a REST Data Source on the FUSION server
(Integrations > Purposes), then switch the Fusion channel on.

## Documents, activity and feedback (release 85)

- **Documents of a record (any application):** an application opens COMMON page 47 (Attachments) with
  `P47_APP_ALIAS`, `P47_SOURCE_PAGE`, `P47_SOURCE_REGION`, `P47_ENTITY_NAME` and `P47_PK1_VALUE`. Register the calling
  page and region under Documents and Records > Attachment Pages (which entities, and whether documents may be added,
  replaced or removed there); register the entity under Document Entities. A record the user may not see shows
  nothing.
- **Platform Activity** (Platform > Platform Activity): the slowest pages, the top users, the errors and every page view
  of the last 30 days, for every registered application.
- **Feedback:** everyone gives feedback with the Feedback link in the navigation bar (another application links to COMMON
  page 173 with `P173_APPLICATION_ID` and `P173_PAGE_ID`). Platform > Usage and Feedback lists it; open one to add a
  follow-up.

## Applications, servers and storage (release 86)

**Register an application.** Platform > Applications > **Register Application** opens a journey of ten steps:
1. **Application** - pick an APEX application of this workspace that is not registered yet (name, alias and schema come
   from APEX), give it a code, a description and its switches.
2. **Roles** and 3. **Users** - the application's roles and who holds them (the usual Role, User and Assign screens).
4. **Shared functions** - the COMMON setup the application's own administrators may manage inside the application.
5. **Setup types**, 6. **Processes**, 7. **Notifications** - what applies to the application.
8. **Document storage** and 9. **Integrations** - where its documents go and which servers it calls.
10. **Review** - check everything, then **Register**. Nothing is saved before Register.

Opening an application shows its page: a header with **Edit** (the journey, at any step), **Disable / Enable** and
**Delete** (only when the application is disabled and nothing refers to it - otherwise the reason is shown), a menu of
the sections and each section with its Add / Edit / Remove actions.

**Scripted onboarding.** Connected as XXFUSION, run `apex/db/admin/onboard-application.sql`: it asks for the APEX
application ID, the code, a description, the e-mail switch and (optional) an administrator user, then registers the
application with the basic setup: role `<CODE>_ADMIN` (every privilege of its features) for that user, shared functions
and processes off, the default notification rules, documents in the database. A re-run changes nothing.

**Servers.** Integrations > Servers > Create Server: pick the APEX Remote Server, its Web Credential and the type; the
screen shows the type's details (OCI Object Storage: region and namespace). Applications only pick servers; they never
define them.

**Document storage.** Attachments > Storage lists every application with its storage state. Open one to set the
application default (server; SharePoint site and document library, Object Storage bucket, UCM security group, account
and document type; folder) and, in the grid, any category that differs - a category value overrides the application's.
Per field: the category, else the application, else the default folder `/#CATEGORY#/#ENTITY_NAME#/#PK1_VALUE#`; when
nothing is set or the setup is incomplete, documents are kept in the **database** (the screen says "incomplete - using
database"). Documents already stored stay where they are.
