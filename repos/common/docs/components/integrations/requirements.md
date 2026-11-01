# Integrations - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Integrations

- **Purpose:** outbound connections and their log.
- **What it does:** servers and credentials set up once; integration purposes; a transmission log in which every call can be retried.
- **Why:** every outbound call is logged and traceable.

* **How it works:** every call goes through COMMON with the server's credential and is written to the transmission log.
* **How it's built:** *APEX:* web credentials, REST data sources, `APEX_WEB_SERVICE`, forms and reports. *Custom:* `XXFND_INTEGRATION_PKG`, 6 tables, 2 views.

- **DB objects:** *Own:* Tables: XXFND\_INTEGRATION\_CALLS, XXFND\_INTEGRATION\_ENDPOINTS, XXFND\_INTEGRATION\_PURPOSES, XXFND\_SERVERS, XXFND\_SERVER\_TESTS, XXFND\_TRANSMISSIONS; Views: XXFND\_INTEGRATION\_CHANGES\_V, XXFND\_SERVERS\_V; Packages: XXFND\_INTEGRATION\_PKG; Triggers: XXFND\_INT\_PURPOSES\_MC. *Uses:* XXFND\_APPROVAL\_PKG, XXFND\_AUDIT\_PKG, XXFND\_LOOKUP\_PKG, XXFND\_LOOKUP\_VALUES\_VL.

* **Shared components:** App items: G\_ADMIN\_APP, G\_ADMIN\_LOCK; Authorizations: page-create, page-manage, page-submit, page-view; Breadcrumb: breadcrumb; LOVs: lov-applications, lov-approval-status, lov-capture-method; Lists: administration; Page groups: administration.

- **Planned (future integrations):** REST data sources prepared but not yet connected: `OUTLOOK_MESSAGES` (Outlook mail), `SHAREPOINT_DRIVES` (SharePoint document libraries) and `UCM_CONTENT` (Oracle UCM content). They stay in COMMON for the integration roadmap.

## Change - Servers and users from APEX (COMMON 109)

- Servers map the workspace's APEX Remote Servers and Web Credentials (listed read-only on Servers); COMMON keeps only the mapping.
- OCI region and namespace are read from the Remote Server URL; the SharePoint / Outlook OAuth token URL comes from an Authentication Remote Server.
- Users: account status (Active / Locked / SSO), failed sign-ins, Lock and Unlock Account.

## Change - Endpoints from REST Source Catalogs (COMMON 110)

- An API call = Remote Server (URL) + Web Credential + REST Source Catalog service (endpoint), all kept in APEX Workspace Utilities.
- A purpose picks a Catalog Service; the call uses the service's endpoint path on the purpose's server, with the server's Web Credential (else the catalog's). Without a catalog service the REST Data Source is used.

## Change - Servers linked to APEX Remote Servers, REST Source Catalogs (COMMON 112)

- A server is linked to its APEX Remote Server; its name and URL are always read from it (a change in Workspace Utilities shows at once). The Web Credential is picked from the workspace's credentials. Type, description and enabled are set when the server is added; state, last call, last test and last error are shown as before.
- The APEX Remote Servers list shows the COMMON server linked to each remote server, or Add (opens the Server form filled in).
- A server has many REST Source Catalogs; a purpose picks its endpoint from the services of its server's catalogs.
- The Server form lists the REST Data Sources of every application in the workspace that use its remote server.
- The Fusion Integration Application route is removed (column dropped).
- Fusion Objects is removed; Fusion endpoints come from the REST Source Catalogs.

## Removed - Fusion Objects (COMMON 112)

The Fusion Objects engine (BICC / REST metadata harvester, replicas, drift) was removed; Fusion endpoints come from the APEX REST Source Catalogs on the server (COMMON 110 / 112).
