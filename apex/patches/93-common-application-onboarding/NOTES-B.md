# Release 86 - part B: workspace servers and document storage per application (notes for the integrator)

COMMON only (app 135, XXFUSION). Nothing of KYC (f134, KYC-only scripts) was changed.

## Model
- **Servers** (`XXFND_SERVERS`, 05b): one row per server, defined once by the COMMON administrator. `SERVER_CODE` =
  the APEX Remote Server static ID; `CREDENTIAL_STATIC_ID` = the APEX Web Credential (empty: of a COMMON REST Data
  Source on the server, else `<code>_CREDENTIALS`); `SERVER_TYPE` = OBJECT_STORAGE (OCI_REGION, OCI_NAMESPACE),
  SHAREPOINT (OAUTH_TOKEN_URL), UCM | FUSION, REST, OUTLOOK (OAUTH_TOKEN_URL); `BASE_URL` only while no Remote Server
  exists (copied endpoints); `ENABLED_FLAG`. No SFTP. Database = no server.
- `XXFND_SERVERS_V` (05b): server_code, server_name, server_type, server_type_name, usage (STORAGE / INTEGRATION),
  base_url (Remote Server, else copied URL, else the OCI region URL), credential_static_id (effective), health
  (last_call, last_error, last_test), missing, status (OK / INCOMPLETE / DISABLED / FAILED), status_text.
- **Storage** (`XXFND_STORAGE_CONFIG`, checked steps in 14): new columns SERVER_CODE (FK4 to XXFND_SERVERS),
  BUCKET_NAME; STORAGE_TYPE, ENDPOINT_CODE, FOLDER_PATH_TEMPLATE nullable; CK1/CK2 dropped, CK4 (type list incl.
  OBJECT_STORAGE, DATABASE). SHAREPOINT_SITE_ID / _DRIVE_ID = site / document library. ENTITY_NAME, ENDPOINT_CODE,
  PRIORITY kept, no longer read. Row with CATEGORY_CODE empty = the application default; APPLICATION_CODE empty =
  COMMON (the instance, the usual COMMON convention); a category row overrides any field (server too; STORAGE_TYPE
  DATABASE = this category in the database). Unique U2 = one enabled row per application + category (U1 dropped).
- `XXFND_APP_STORAGE_V` (14): one line per registered application (category empty) and per category it uses (its own
  + shared ones): own values (server_code, server_type, site, library, bucket, security_group, account, document_type,
  folder), `effective_*` (category, else application, else folder `/#CATEGORY#/#ENTITY_NAME#/#PK1_VALUE#`),
  `effective_storage_type` (what an upload uses), `state` ('OK' / 'INCOMPLETE - using database') and
  `incomplete_reason`. COMMON appears as APPLICATION_CODE 'COMMON'.
- Documents keep their location: `XXFND_DOCUMENTS.SERVER_CODE`, `STORAGE_CONTAINER` (library / bucket), set on upload
  and back-filled by 29 for the documents already stored.

## Code (owning scripts)
- 00: `XXFND_DDL_PKG.DROP_OBJECT` also drops TRIGGER and TABLE (DDL recorded, table to the recycle bin, not purged).
- 05b `XXFND_INTEGRATION_PKG`: `T_SERVER` + server_type, oauth_token_url, oci_region, oci_namespace; `SERVER` reads
  XXFND_SERVERS_V first, then an undefined Remote Server (no endpoint fallback any more); `SAVE_SERVER` (type decides
  the kept details; optional p_base_url), `DELETE_SERVER` (ORA-20342 when used), `SAVE_PURPOSE` (p_new Y/N,
  ORA-20343), `DELETE_PURPOSE` (ORA-20344). Purposes: column SERVER_CODE + FK2 + index N2 (checked).
- 14 `XXFND_ATTACH_PKG` (release 86 block before the spec + transport section; part A's MOVE_DOCUMENTS is separate):
  `RESOLVE_STORAGE` (same signature) reads XXFND_APP_STORAGE_V in trusted mode (VPD admin scope does not hide the
  setup from normal users) and returns the effective values as one rowtype; DATABASE when nothing applies or the setup
  is incomplete. New `STORAGE_APPLICATION` (entity's app, else category's, else COMMON), `SAVE_APP_STORAGE`,
  `SAVE_CATEGORY_STORAGE` (ORA-20333/4/5; fields the effective type does not use are cleared; an emptied category row
  stays - documents may refer to it), `OBJECT_STORAGE_URL`, `OBJECT_NAME`. OCI Object Storage transport (private
  OS_PUT / OS_GET / OS_DELETE through APEX_WEB_SERVICE with the server's Web Credential, logged via
  XXFND_INTEGRATION_PKG.LOG_START/LOG_END; each version its own object `<folder>/<12 hex>_<file>`; ORA-20336).
  Downloads / new versions use the document's own server and container (`DOCUMENT_LOCATION`); `#CATEGORY#` token.
- 15e: OUTLOOK_GRAPH seeded into XXFND_SERVERS (disabled) instead of the endpoint table.
- 04b / 09d / 16i: XXFND_INTEGRATION_ENDPOINTS removed from the config-table list, `SCOPED_TABLES` and the 16i column
  list / comment. **09d is also changed by part A** - my change is the one line in `SCOPED_TABLES`.
- 21c: setup type SERVERS (XXFND_SERVERS, 120/121, P121_SERVER_CODE) replaces INTEGRATION_ENDPOINTS; DOCUMENT_STORAGE
  level B; XXFND_SETUP_ROWS_V storage rows open 137 with P137_APPLICATION_CODE.
- 22: INTEGRATIONS module state = servers incomplete or failing (XXFND_SERVERS_V); description says servers.
- 25: CK4 only while CK5 does not exist; trigger XXFND_INT_ENDPOINTS_RO only while the table exists (25 re-runs after 29).
- **29-servers.sql** (install 222 / upgrade 182, COMMON): lookups SERVER_TYPE, STORAGE_TYPE + OBJECT_STORAGE/DATABASE;
  copy endpoints into XXFND_SERVERS (dynamic SQL; mapping UCM/SHAREPOINT/FUSION/OUTLOOK*/else REST; INACTIVE ->
  disabled); seed FUSION, UCM_MAIN, SHAREPOINT_MAIN when missing; purposes SERVER_CODE := endpoint, CK4 -> CK5;
  DOCUMENT_STORAGE level B; conversion of old storage rules; U2; documents back-fill; drop trigger, FKs (storage FK3,
  purposes FK1, transmissions FK1) and the table; config-table row; setup types; recompile.
- Deviation from CONTRACT.md: XXFND_SERVERS / XXFND_SERVERS_V and the purpose column are created in 05b, the storage
  and document columns and XXFND_APP_STORAGE_V in 14 (all checked steps), not in 29 - their packages and 15e / 21c /
  22 run before 29 on install and upgrade, so creating them in 29 would leave invalid objects / ORA-00942 in between.
  29 keeps the conversion, copies, drops and setup changes.

## Conversion rules (old storage rows: ENDPOINT_CODE set, SERVER_CODE empty)
Processed enabled first, generic (no entity) first, then PRIORITY. Application = row's, else entity's, else category's
(COMMON -> empty). Server = old endpoint (copied to XXFND_SERVERS in step 2). A row whose application + category
already has an enabled rule is disabled (kept). A shared enabled rule (no application anywhere) is also copied as the
rule of every registered application without one. Documents get SERVER_CODE / STORAGE_CONTAINER from their row.
On the shared DB: row 1 (shared default, disabled, UCM_MAIN) converted, stays disabled -> COMMON and KYC use the
database (as before).

## Pages (same menu places, features, privileges)
- 120 Servers: IR on XXFND_SERVERS_V (type, use, URL, credential, state, health), Create Server; endpoints region removed.
- 121 Server: modal form on XXFND_SERVERS (item P121_SERVER_CODE = Remote Server LOV, read-only once saved); type
  decides the fields (DAs); Test Connection kept; Create / Apply / Delete through SAVE_SERVER / DELETE_SERVER.
- 122 / 123 Purposes: Server column; P123_SERVER_CODE (integration servers); P123_ENDPOINT_CODE removed; saves through
  SAVE_PURPOSE / DELETE_PURPOSE (formAutoRowProcessing removed). P123_APPLICATION_CODE keeps a preset value (the
  default applies only when empty) - part C opens 123 with it through APEX_PAGE.GET_URL (page has argument checksum).
- 136 Document Storage: one line per application (XXFND_APP_STORAGE_V), link to 137; Create Storage Rule removed.
- 137 Application Storage (modal dialog, 1100 px; alias kept STORAGE-RULE): P137_APPLICATION_CODE; application
  default items (server LOV of storage servers, empty = Database; fields by server type) + interactive grid of the
  categories (update only) saved by IG process with PL/SQL target -> SAVE_CATEGORY_STORAGE; Apply Changes ->
  SAVE_APP_STORAGE. LOV lov-endpoints removed (lov-endpoint-status / -type still exist, unused).

## Tests (shared DB, under the flock lock, app imported from this worktree)
- r87_servers_test.sql: 53 PASS, 1 FAIL - "no PL/SQL names XXFND_INTEGRATION_ENDPOINTS": the only source line left is
  XXFND_APPLICATION_PKG.SCOPED_TABLES in the DB, i.e. part A's 09d as installed; my 09d removes it. Passes once the
  merged 09d is installed. 0 invalid objects in XXFUSION. 29 run twice (re-run) without error.
- r87_servers_ui.py: 33 PASS, 0 FAIL.
- r83_integrations_test.sql: 22 PASS (two checks updated for release 86: endpoints retired, CK5);
  r83_integrations_ui.py: all passed (updated: no owner column / endpoints region, new item ids).
- r81_documents_test.sql: 12 PASS; r81_documents_ui.py: all passed.
- Not done here: fresh install / upgrade / App Builder import cycle (integrator, with the merged release).

## KYC references found (not changed - KYC is done later by the user)
- `apex/db/18-seed-data-and-administrator-part-2-of-2.sql` (KYC): merges into XXFND_INTEGRATION_ENDPOINTS and inserts
  storage rows / purposes with ENDPOINT_CODE - fails (ORA-00942) once COMMON 86 dropped the table; must seed
  XXFND_SERVERS / the new storage form instead.
- `apex/db/16e-party-pkg.sql` (KYC): comment of XXCMP_PARTY_REGISTRY_CHECKS.ENDPOINT_CODE names the table.
- XXCUS has a synonym XXFND_INTEGRATION_ENDPOINTS (now dangling; XXCUS has many other invalid synonyms already).

## Other notes
- `XXFND_INTEGRATION_CHANGES_V` (09) still summarises purposes with ENDPOINT_CODE (column kept, now empty for new
  rows); not changed (09 runs before 05b adds SERVER_CODE).
- Shared DB lock incident: `db.lock` was held forever by dockerd (it inherited the fd from a `dbup.sh` started under
  flock), so every waiter hung. I renamed it to `db.lock.stale-held-by-dockerd` and created a new empty `db.lock`;
  start dbup.sh outside flock (or close fd 3) to avoid it.
