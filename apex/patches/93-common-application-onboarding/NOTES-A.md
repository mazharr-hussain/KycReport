# Release 86 - part A notes for the integrator (registration and onboarding, database only)

## What changed
- **Registration routines** (each in the package that owns the table; adds a row only when missing, never changes
  what an administrator changed, a re-run does nothing; refuses an application that is not in XXFND_APPLICATIONS
  with XXFND_APP_NOT_REGISTERED (ORA-20180), a row of another application with XXFND_REG_OTHER_APP (ORA-20186), an
  unknown parent row with XXFND_REG_UNKNOWN (ORA-20187); no APEX session needed). COMMON's setup rows are stored as
  instance rows (APPLICATION_CODE null, as 21c does); roles always keep their application.
  - XXFND_PRIVILEGE_PKG (09b): REGISTER_FEATURE, REGISTER_FEATURE_PAGE (app alias of the application),
    REGISTER_PRIVILEGE, REGISTER_ROLE, ADD_ROLE_PRIVILEGE (additive), REGISTER_SOD_RULE (canonical order).
  - XXFND_VPD_PKG (09b): REGISTER_DATA_RULE (assigned to the role by trigger XXFND_DATA_RULES_ASSIGN).
  - XXFND_LOOKUP_PKG (05c): REGISTER_LOOKUP_TYPE, REGISTER_LOOKUP_VALUE (+ Arabic meaning).
  - XXFND_DFF_PKG (10 spec / 11 body): REGISTER_VALUE_SET, REGISTER_FLEXFIELD (en/ar names + protected GLOBAL context;
    ORA-20190 when the table has another flexfield), REGISTER_CONTEXT (+ Arabic name).
  - XXFND_ATTACH_PKG (14): REGISTER_ENTITY (en/ar), REGISTER_CATEGORY (English base row + Arabic TL, as the seeds),
    REGISTER_ATTACHMENT_PAGE (function + block + block entity; ORA-20191 when the page is another function's),
    **MOVE_DOCUMENTS**(entity, from pk1, to pk1): every link of the record (removed ones too) moves; versions follow
    (they hang off BASE_DOCUMENT_ID); moved documents are sequenced after the target's; nothing when nothing to move;
    stored files stay where they are. COPY_ATTACHMENTS unchanged.
  - XXFND_NOTIFY_PKG (15): REGISTER_TEMPLATE (en + ar), SET_RULE_ENABLED.
  - XXFND_WORKFLOW_PKG (15): REGISTER_TASK_SETTING, SET_PROCESS_ENABLED (WORKFLOW_ENABLED_FLAG).
  - XXFND_APPROVAL_RULE_PKG (15d): REGISTER_DEFAULT_RULE (rule + conditions 'ATTR=value' + steps
    'name=ROLE=code' / 'name=USER=user' / 'name=REQUESTER', only while the type has no rule; ORA-20188 bad step).
  - XXFND_APPROVAL_PKG (spec 05 and 05-upgrade, body 15): REGISTER_CONFIG_TABLE.
  - XXFND_INTEGRATION_PKG (05b): REGISTER_PURPOSE (APPROVED from a script; PENDING_APPROVAL from an APEX session via
    the maker-checker trigger). Part B adds SERVER_CODE to purposes: add it as a parameter there if wanted.
- **XXFND_APPLICATION_PKG (09d)**, exactly the contract interfaces: SAVE_APPLICATION, ONBOARD, SET_ENABLED,
  DELETE_BLOCKER, DELETE_APPLICATION, SAVE_FUNCTIONS (page 161's grid logic; page 161 not touched); plus
  REGISTERED_CODE, SETUP_CODE, ASSERT_SAME_APPLICATION (the one registration rule every REGISTER_* uses).
  - Name / alias / parsing schema come from APEX_APPLICATIONS of COMMON's workspace. ORA-20181 not in the workspace,
    ORA-20182 registered under another code, ORA-20183 bad code. Create = register: grants (REGISTER_APPLICATION),
    APEX ID, function rows (not managed), process rows (XXFND_WORKFLOW_PKG.SYNC_PROCESSES).
  - ONBOARD: SAVE_APPLICATION (a re-run keeps description, enabled and e-mail switches) + shared processes made now
    and not the application's own APEX workflows (e.g. RFI) off + role <CODE>_ADMIN with every privilege (View, Create,
    Manage) of the application's features; on a re-run only privileges registered since the last onboarding (role
    LAST_UPDATE_DATE is the mark) - a privilege an administrator removed stays away. Admin user via
    XXFND_USER_PKG.BOOTSTRAP_ADMIN. Default notification rules (application empty) apply as they are; storage: nothing
    (database until set up).
  - DELETE_BLOCKER: COMMON never; enabled -> "Disable ... first"; else counts every XXFND_ table with APPLICATION_CODE
    (except the application's own standard rows), features, feature pages, config tables, documents of its entities,
    roles in use (users, data rules, SoD, task escalation, approval steps), APEX tasks and workflows (trusted read).
    DELETE_APPLICATION (ORA-20184) deletes function rows, process rows, setup-type rows, unused roles, the row.
  - In an APEX session SAVE_APPLICATION / ONBOARD / SET_ENABLED / DELETE_APPLICATION / SAVE_FUNCTIONS need
    APPLICATIONS.MANAGE; SET_PROCESS_ENABLED APPLICATIONS or WORKFLOW_SETUP Manage; SET_RULE_ENABLED APPLICATIONS or
    NOTIFICATIONS Manage (XXFND_NOT_ALLOWED, ORA-20002). Scripts (no APEX session) are allowed.
- **XXFND_USER_PKG.BOOTSTRAP_ADMIN (16j)**: small fix needed by ONBOARD - an existing user without an employee
  (LOCAL) gets the role on the user itself (before, a new employee was made and the user trigger failed on the name).
- **04b**: the KYC row merge into XXFND_APPLICATIONS and the `schema_name = 'XXCUS' where KYC` update are removed (an
  existing row is kept). Checked: no COMMON install script depends on the KYC row (17's KYC lookups are skipped
  unless XXCMP_PARTIES exists; 18c / 19b are KYC scripts; 14's `nvl(APP_ALIAS, 'KYC')` is a runtime default).
  The update was removed too (not only kept as harmless): it names KYC in COMMON, and onboarding takes the schema
  from APEX.
- **28-registration.sql** (new; install 221 / upgrade 181, apps COMMON): catalogue messages XXFND_APP_* /
  XXFND_REG_* (-20180..-20191, texts kept when changed) and the recompile. No table change, so no checked step.
- **apex/db/admin/onboard-application.sql** (new): prompts APEX application ID, code, description, e-mail switch,
  admin user; calls ONBOARD; re-runnable.

## Files
apex/db/04b-applications-and-users.sql, 05-core-packages-part-1-of-2.sql, 05-core-packages-part-1-of-2-upgrade.sql,
05b-integration-pkg.sql, 05c-lookup-pkg.sql, 09b-security-framework-objects.sql, 09d-application-pkg.sql,
10-flexfield-runtime-part-1-of-2.sql, 11-flexfield-runtime-part-2-of-2.sql, 14-attachments.sql, 15-workflow.sql,
15d-approval-setup.sql, 16j-user-pkg.sql, 28-registration.sql (new), manifest.json, admin/onboard-application.sql (new);
apex/tests/r86_registration_test.sql (new), apex/tests/r86_test_apps.sql (new).

## Merge notes
- Every package change is an **appended block** at the end of the spec and of the body (nothing edited in the middle,
  except 16j BOOTSTRAP_ADMIN and 15d's own new routine). 14 and 05b blocks are marked "Release 86 (part A)" for the
  merge with part B's storage / server changes; 09d also has part B's one-line SCOPED_TABLES change - both merge cleanly.
- Fresh install order: 09b (95) and 09d (98) run before 09c / 09e / 15 / 15d / 16j, so the new code reaches
  later columns and packages by name (dynamic SQL, commented); 05c (56) calls XXFND_APPLICATION_PKG and
  XXFND_ERROR_PKG by name. No compile error on a fresh install.
- Error numbers used: -20180..-20188, -20190, -20191 (B uses -20333/-20334).

## Tests (shared DB)
- Part A blocks were injected into the packages as installed on the shared DB (keeps part B's versions there), then
  16j, 04b, 28 run; the injection and the scripts were run twice: no error, 0 invalid objects in XXFUSION.
- apex/tests/r86_test_apps.sql (XXCUS) made test APEX apps 860 R86TEST and 861 R86DEL (empty; kept).
- apex/tests/r86_registration_test.sql (XXFUSION): 98 PASS, 0 FAIL, twice (second run = re-run of everything).
  Rows kept: application R86TEST and its R86_* rows, table R86_DFF_TEST, test documents; R86DEL is onboarded and
  deleted by each run. The admin script was run once on R86TEST (re-run): "Onboarded R86TEST".

## For ARCHITECTURE.md (integrator)
- Release 86 (part A): registration routines per component (list above), XXFND_ATTACH_PKG.MOVE_DOCUMENTS,
  XXFND_APPLICATION_PKG onboarding API (SAVE_APPLICATION, ONBOARD, SET_ENABLED, DELETE_BLOCKER, DELETE_APPLICATION,
  SAVE_FUNCTIONS, REGISTERED_CODE / SETUP_CODE / ASSERT_SAME_APPLICATION), XXFND_WORKFLOW_PKG.SET_PROCESS_ENABLED,
  XXFND_NOTIFY_PKG.SET_RULE_ENABLED, admin script onboard-application.sql, 28-registration.sql (install 221 / upgrade
  181); COMMON no longer seeds the KYC row (04b). Uses: 09b, 09d, 15, 16j; used by: part C pages 165/166, every
  application's install (registration) and the onboarding script.

## Open points
- XXFND_SHARE_PKG.GRANT_TO prints "skipped: grant select on XXFND_APP_STORAGE_V / XXFND_SERVERS_V ... ORA-01720"
  for XXCUS on the shared DB (part B's views over APEX_WORKSPACE_REMOTE_SERVERS cannot be granted with grant option);
  shows on every registration. For part B / the integrator.
- Older tests (r73_common_test.sql, r80_platform_test.sql, common_*_ui.py) refer to the KYC application row; on a
  COMMON-only fresh install that row no longer exists.
- REGISTER_DATA_RULE does not attach the VPD policy (the application's own install runs APPLY_POLICIES in its schema).
