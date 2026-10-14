# COMMON application – installation

One package: `COMMON-Application-APEXlang_<N>.zip` - the application with its database scripts (Supporting
Objects). The ADMIN script, needed only when XXFUSION does not exist yet, is `apex/db/admin/create-xxfusion-schema.sql`
in the repository.

## Steps
1. **App Builder → Import** the application zip into the workspace → **Parsing Schema = XXCUS** (App Builder's
   APEXlang install runs as the REST-enabled schema XXCUS; choosing XXFUSION there fails with ORDS
   "Not allowed to install in workspace ... or schema XXFUSION" and the page goes blank) →
   **Install Supporting Objects: No**.
   Then: **App Builder → COMMON → Edit Application Definition → Security → Database Session → Parsing Schema =
   XXFUSION → Apply Changes**, then **Utilities → Supporting Objects → Install Supporting Objects**.
   - If XXFUSION is not in the list, run `apex/db/admin/create-xxfusion-schema.sql` as ADMIN (it creates XXFUSION if
     needed, grants and adds it to the workspace).
   - Installed while the parsing schema is still XXCUS, the scripts do nothing except report **ORA-20901 ACTION
     NEEDED** (script 00b); switch the parsing schema as above and install again.
2. The first script, **00a Prerequisites check**, checks the privileges of XXFUSION. If one is missing the
   install reports **ORA-20900 ACTION NEEDED** with the exact statements, for example:
   ```
   grant execute on sys.dbms_rls to XXFUSION;
   grant execute on sys.dbms_crypto to XXFUSION;
   ```
   Run them as **ADMIN** (Database Actions → SQL), then come back:
   **App Builder → COMMON → Utilities → Supporting Objects → Install Supporting Objects**.
   Every script can be re-run; errors in later scripts of the failed run came from the same missing privilege.
3. Sign in to COMMON. The user who installed it is the first Common Administrator. COMMON is for IT only (release 71):
   only users with the role Common Administrator (COMMON_ADMIN) can sign in; give it to the IT administrators.

## Order with the business applications
Order: COMMON → (once) the ADMIN move script → KYC. Since release 68 KYC opens the shared setup screens in COMMON.

The shared XXFND_ objects live only in XXFUSION; KYC (XXCUS) reaches them through synonyms and grants. Always
install / upgrade **COMMON first**, then KYC.

## Upgrade
Import the newer zip over the existing COMMON application the same way as step 1: **Parsing Schema = XXCUS**,
**Install Supporting Objects: No**; then **Edit Application Definition → Security → Parsing Schema = XXFUSION →
Apply Changes**, then **Utilities → Supporting Objects → Install Supporting Objects** (runs the upgrade scripts;
data is kept). The same prerequisites check runs first.

Delegated administration (release 73): IT can let an application's administrators maintain a common function for
their application (COMMON → Applications → the application → Managed in the Application). They open it from their
own application's Administration menu, in a dialog, signed in through the shared session - not by signing in to
COMMON.

## Install or upgrade from SQL Developer Web (release 74)
Instead of the import steps above: as **ADMIN**, Database Actions → SQL → open
`COMMON-Application-SQL-Install_<N>.sql` → **Run Script (F5)**. The script sets the workspace (XXCUS), the application
ID (135) and the parsing schema (**XXFUSION** - no manual switch), runs the supporting objects (install scripts on a
new database, upgrade scripts on an existing one; data kept) and installs the application. Then run the KYC script of
the same release. Release 74 needs no new database privilege.


## Release 76 (COMMON + KYC)
Install COMMON 76 first and wait until it has finished, then KYC 76 (KYC stops with ORA-20904, changing nothing, when COMMON 76 is not there yet). From this release the delivery is the APEXlang zip of each application (App Builder import) - no SQL Developer Web install script. QD only, once after both: run `apex/db/admin/qd-users-and-roles.sql` connected as XXFUSION (users and roles; first password Welcome#2026, changed at first sign-in). Upgrades no longer give back a privilege removed from a role in the console.


## Release 84 (COMMON)
Release 84 (COMMON only, patch 91): workflow processes and notifications driven by data. The request for information
(RFI) and the configuration change approval are APEX workflows of COMMON (Shared Components > Workflows: RFI,
CONFIG_CHANGE) with their task definitions; XXFND_RFI_PKG and XXFND_APPROVAL_PKG keep the data and the rules and no
longer create tasks. An outside person answers on the public page Provide Information (one-time link), which continues
the waiting workflow. Notifications come from data (Workflow > Notification Delivery): channels (in the application -
the bell and Notifications list, e-mail, push, Fusion prepared and off), events, rules (who, on which channel) and the
queries that find the people; the wording stays on Notification Templates (English and Arabic). COMMON becomes a
progressive web app with push notifications; each person turns push on per device (Notifications > This device).
New COMMON settings MAIL_FROM (sender; empty = no e-mail) and MAIL_FOOTER: set them on Application Settings after the
upgrade. The e-mails of a record (send, record a received one, history) are COMMON pages Communications and E-mail.
An hourly COMMON automation "Task deadlines" raises the reminders and escalations of every application.
Upgrade as usual (Install Supporting Objects, upgrade scripts). In a new workspace the push key pair is made by the
install script while no device is subscribed. **KYC needs its own release** (its RFI and configuration change task
definitions and pages move to COMMON's).

## Release 83 (COMMON)
Release 83 (COMMON only, patch 90): Integrations use APEX's own components. The servers COMMON calls are APEX Remote
Servers (FUSION, UCM_MAIN, SHAREPOINT_MAIN, OUTLOOK_GRAPH) and their secrets APEX Web Credentials, kept by the workspace
administrator (installed with placeholder URLs and no secrets; see ADMIN-GUIDE.md, "How to change a server"). Endpoints
are REST Data Sources of COMMON (FUSION_HCM_WORKERS); purposes point to them. XXFND_INTEGRATION_PKG is the one call
procedure: every call is logged with what is needed to retry it, and the Transmission Log shows APEX's own web service
log. The registered endpoints are read-only and retiring (their rows stay). The Fusion HCM sync is a COMMON automation,
installed disabled: switch it on once the FUSION server and its credential are set. Upgrade as usual (Install
Supporting Objects, upgrade scripts). **KYC needs its own release** (its HCM sync automation and FUSION_* settings go).

## Release 82 (COMMON)
Release 82 (COMMON only, patch 89): Workflow uses one package per component. XXFND_WORKFLOW_PKG holds the workflow
runtime, the workflow and e-mail switches and the task helpers; XXFND_NOTIFY_PKG holds notifications and the e-mails per
record. XXFND_TASK_PKG, XXFND_WORKFLOW_SWITCH_PKG, XXFND_COMMUNICATION_PKG and the unused view XXFND_PENDING_APPROVALS_V
are dropped (their DDL is kept in XXFND_DROPPED_OBJECTS). The Process Catalogue lists the Request for Information
process of every application and who acts on each process, and asks before a workflow is switched off. A request for
information goes to the requester unless someone else is chosen; an outside recipient gets the e-mail in the chosen
language. E-mails use the APEX Email Template XXFND_STANDARD (layout, links, right to left for Arabic); the
Notifications screen keeps only the wording (plain text, English and Arabic) with a preview and "Send Test to Me".
New screens: My Tasks (tasks of every application) and the Workflow Monitor (act on anyone's behalf, Workflow Monitor -
Manage). Upgrade as usual (Install Supporting Objects, upgrade scripts). **KYC needs its own release for the new names**
(decided: no wrappers).

## Release 81 (COMMON)
Release 81 (COMMON only, patch 88): Documents and Records use one package per component. The document store transport
(Oracle UCM, SharePoint, database) is now private code of XXFND_ATTACH_PKG; XXFND_ATTACH_STORE_PKG is dropped (its DDL
is kept in XXFND_DROPPED_OBJECTS). New XXFND_RETENTION_PKG is a placeholder that flags, archives and deletes nothing.
The Retention screen (112) shows only "Retention is not active yet". Document Entity (131) saves its display name
through XXFND_ATTACH_PKG. Upgrade as usual (Install Supporting Objects, upgrade scripts).

## Release 80 (COMMON)
Release 80 (COMMON only, patch 87): Platform and Reference Data use one package per component - XXFND_APPLICATION_PKG
(applications, setup types, administration scope), XXFND_APP_SETTING_PKG, XXFND_LOOKUP_PKG and XXFND_DFF_PKG; the old
packages and two unused views are dropped. The level shown as "All applications (instance)" now reads "Workspace (all
applications)". Upgrade as usual (Install Supporting Objects, upgrade scripts). KYC needs its own release for the new
names (decided: no wrappers).

## Release 79 (COMMON)
Release 79 (COMMON only, patch 86): Security works as one module. A data access rule is assigned to users and to roles
(existing rules keep their role as first assignment); a user sees what any rule of theirs or of their roles allows. The
User, Role and Data access rule screens each show their record on top with two tabs and share one Assign dialog;
the User screen shows the Effective access. Users have a language (default English). New Super Administrator role
(nobody holds it until granted). XXFND_SECURITY_PKG and XXFND_AUTH_PKG are replaced by XXFND_USER_PKG,
XXFND_PRIVILEGE_PKG and XXFND_INTEGRATION_PKG: **the KYC application stops working until its own release uses the new
names** (decided: no wrappers). After the upgrade, run `apex/db/admin/qd-users-and-roles.sql` again for the QD users
(department rules per user). Upgrade as usual (Install Supporting Objects, upgrade scripts).

## Release 78 (COMMON)
Release 78 (COMMON only, patch 85): COMMON is organised into six modules (Platform, Security, Reference Data,
Documents and Records, Workflow, Integrations). The menu is Home and the six modules; a module opens its page with its
components; Home shows the modules with their state; Approval Setup and Optional Features have their own menu entries
(rights copied from Workflow Setup / Application Settings); new page Subscriptions under Platform > Applications.
Upgrade as usual (Install Supporting Objects, upgrade scripts). KYC is not changed.

## Release 77 (COMMON)
Release 77 (COMMON only): removes the unchanged release 76 error-log retention policy; no retention policy is seeded any more. Independent of KYC 77.
