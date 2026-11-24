# COMMON 123 - Screen fixes, routines for applications, status colours, approval group column

On top of COMMON 122. Application, database and pipeline changes.

| Issue | Change |
|---|---|
| I-067 (#227) | Pipeline step 8.3a lists the errors the application logged while the browser test opened its pages (page, user, message) as notices - pages 137 and 108 log one without showing an ORA- code. The cause is fixed in a later release, from that list. |
| I-020 (#155) | Server (page 121): another APEX Remote Server shows its name, URL, region, namespace and REST Data Sources at once (dynamic action), not only after saving. |
| I-022 (#157) | Purpose (page 123): the Catalog Service field explains why its list can be empty. |
| I-012 (#147) | `XXFND_WORKFLOW_PKG.ADD_DELEGATION` / `END_DELEGATION`: delegations through routines. |
| I-013 (#148) | `XXFND_APPROVAL_RULE_PKG.SET_RULE_ENABLED` and `XXFND_USER_PKG.SET_ROLE_ENABLED`: an application switches its approval rules and role grants off and on through routines. |
| I-026 (#161) | Approval groups in their own column `GROUP_CODE` (rule levels and approval steps), moved from `ROLE_CODE` on upgrade; constraint CK7 replaced by CK8, foreign key FK2 to the groups; page 149 shows Role and Group columns; pages 148 and 154 follow. |
| I-014 (#149) | `XXFND_LOOKUP_PKG.UPDATE_LOOKUP_VALUE`: an application changes its own lookup values (meaning, description, tag, tone, Arabic meaning). |
| I-010 (#145) | Lookup values get a `TONE` (success, warning, danger, info, neutral), set at registration (`P_TONE`) or by update, read with `LOOKUP_TONE`, edited on page 102 and shown by `XXFND_LOOKUP_VALUES_VL`. `XXFND_UI_PKG.STATUS_TONE` uses it first; its own KYC codes remain only as a fallback until KYC sets its tones. |
| I-011 (#146) | Application Setting (page 10023): another application's setting is read-only, with a note and an Open button for that application (APEX changes a setting only in the running application). |
| I-3B2 (#166) | Pages 175 and 177 share the LOV `DM_APPLICATIONS`. The other repeated lists filter on their own page's fields and stay on their pages. |
| I-053 (#209) | Step 7.5 (DBSAT) finds the `dbsat` launcher wherever it is in the downloaded zip (in a folder, or in a zip inside it): the first run with the user's download failed with `./dbsat: No such file or directory`. |

**Database (install and upgrade, re-run safe):** `05c` step 01 adds `XXFND_LOOKUP_VALUES.TONE` with check CK3 (before
the package that reads it); `15d` step 23 adds `GROUP_CODE` to `XXFND_APPROVAL_RULE_STEPS` and
`XXFND_APPROVAL_TXN_STEPS`, moves the group codes, replaces CK7 by CK8 and adds FK2. No base CREATE changed.

**For KYC (later, with the KYC changes):** set the tone of its status lookup values (then `STATUS_TONE`'s KYC codes can
go); use `ADD_DELEGATION`, `SET_RULE_ENABLED` and `SET_ROLE_ENABLED` in its tests instead of direct table writes.

Checked offline: the COMMON build (install and upgrade scripts, the new LOV registered by step 1.1a), the PR static
checks (0 errors), `bash -n`, shellcheck, the pipeline dry run; APEXlang attributes checked against the APEX skill
(26.1 inventory: `inlineHelpText`, `readOnly`, `redirectUrl`, IG columns, shared LOV); the SQL reviewed with the DB skill.
