# COMMON 113 - Process catalogue, approval groups, page fixes

Build: `releases/COMMON-Application-APEXlang_113.zip` (application version "Release 113"), on top of COMMON 112.
Built with `repos/common/build.sh --release 113`; checked with the APEXlang validation ("Validation successful"). No
database was run: the DB test `features/approval-setup/tests/r113_approval_groups_test.sql` is for the test database.

## What changes
| Screen | Change |
|---|---|
| 121 Server | Fix: the form opened with ORA-00937 (Server name query). |
| 104 User | Fix: the form failed with "more than supported columns" (Account now starts a new row). |
| 147 Process Catalogue | Approval Processes: one row per process (application, process, rules, approval groups, levels, state); the process opens its Process page. |
| 154 Process (new) | One page per process: its **Approval Rules** (conditions and levels in order; Add Rule) and its **Approval Groups** (members, used by levels; Add Group). |
| 155 Approval Group (new) | Code, name, description, enabled, members: roles (their active users) and users. |
| 149 Approval Rule | A level's approver can be **An approval group** (Role / Group column lists the process's groups). |

## Database
- New tables `XXFND_APPROVAL_GROUPS`, `XXFND_APPROVAL_GROUP_MEMBERS` (15d, with WHO triggers).
- `XXFND_APPROVAL_RULE_STEPS`: approver type GROUP (the group code in ROLE_CODE) - CK3 / CK4 replaced by CK6 / CK7
  (checked step 15d-21).
- `XXFND_APPROVAL_RULE_PKG`: SAVE_GROUP, SET_GROUP_MEMBERS, DELETE_GROUP (only the application's own processes; refused while
  a level uses the group), GROUP_USERS; a GROUP level's approvers are the group's users and the active users of its roles;
  starting an approval is refused when a group has no user.
- Script 41d: pages 154 and 155 belong to the feature Approval Setup.

## Deploy
App Builder > Import `COMMON-Application-APEXlang_113.zip` over COMMON (135), Install Supporting Objects = Yes; or run
`run-release.sql` as XXFUSION, then import the application. A re-run changes nothing.
