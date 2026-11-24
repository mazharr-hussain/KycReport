# COMMON 126 - Users: account status for every administrator; page-error list without dialog noise

On top of COMMON 125. One package change and one pipeline change; no table, page or data change.

| Issue | Change |
|---|---|
| I-095 (#270) | `XXFND_USER_PKG.ACCOUNT_STATUS` reads `ACCOUNT_LOCKED` from `APEX_WORKSPACE_APEX_USERS` instead of `APEX_UTIL.GET_ACCOUNT_LOCKED_STATUS`, which only APEX workspace administrators may call: page 103's Account column is filled for every COMMON administrator and no error is logged per row. |
| I-067 (#227) | The cause of the errors of pages 137 and 108: the browser test opens every page by its URL, and APEX logs "Dialog page ... cannot be rendered" for a dialog page opened outside a dialog (23 dialog pages). Not a page fault: step 8.3a now leaves that message out, so it lists only real page errors. |

Checked offline: `bash -n`, shellcheck, the pipeline dry run; the package change reviewed with the DB skill (bind variable, dynamic SQL as the neighbouring FAILED_SIGN_INS).
