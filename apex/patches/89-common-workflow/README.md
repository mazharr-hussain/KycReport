# Patch 89 - COMMON: Workflow (release 82, COMMON only - C5 Workflow)

## What changes
- **One package per component.** `XXFND_WORKFLOW_PKG` holds the workflow runtime, the workflow and e-mail switches
  (was `XXFND_WORKFLOW_SWITCH_PKG`) and the task helpers (was `XXFND_TASK_PKG`); `XXFND_NOTIFY_PKG` holds the
  notifications and the e-mails per record (was `XXFND_COMMUNICATION_PKG`). The three packages and the unused view
  `XXFND_PENDING_APPROVALS_V` are dropped with the checked `XXFND_DDL_PKG.DROP_OBJECT` (DDL kept in
  `XXFND_DROPPED_OBJECTS`). **KYC stops working until its own release uses the new names** (decided: no wrappers).
- **Process Catalogue (147):** the Request for Information process of every application, who acts on each process
  (Approval Setup rules, or chosen by the user) and a confirmation before an approval workflow is switched off
  ("Records of this process will be approved automatically. Continue?"). The workspace e-mail switch is saved by the
  package.
- **Requests for information:** the requester is the default recipient; an outside recipient gets the e-mail in the
  language chosen when the request is raised (default English). The Approval Setup type "Case request for information"
  is disabled (its rows stay).
- **One task decision** for every application (`XXFND_APPROVAL_RULE_PKG.DECIDE_TASK`: approve, reject, request or
  submit information, add an approver, comment) and **one questions-and-answers history** (`XXFND_QA_HISTORY_V`: task
  comments and RFI questions and answers of a record).
- **Notifications:** every e-mail uses the APEX Email Template `XXFND_STANDARD` of COMMON (layout, link, right to left
  for Arabic). The Notifications screen keeps only the wording - a subject and a plain-text message, in English and
  Arabic - with a preview and "Send Test to Me", and shows which applications use the layout. Older HTML wording is
  converted to plain text once (the HTML column is kept). RFI_RESPONDED and CONFIG_CHANGE_PENDING are disabled.
- **My Tasks (40)** lists the user's tasks of every application; task e-mails link to it; Home shows the open task
  count. **Workflow Monitor (141, 142)** shows every workflow of every application: suspend, resume, retry, terminate,
  and reassign, delegate or release a task on anyone's behalf (Workflow Monitor - Manage).
- **Approval Rule (149):** "Test the Rules" shows the approvers a record with given attributes would get.

## Files
- `db/`: 02 and 06 (comments), 09 (view dropped), 09e (table only), 15 (merged packages, communications table, wording
  columns), 15b removed from the manifest, 15c, 15d, 15e (seeds only), 19c, 21b, 24 (new), `manifest.json`,
  `admin/qd-users-and-roles.sql`
- `app/`: `application.apx` (Release 82); pages 1, 40 (new), 109, 110, 141 (new), 142 (new), 147, 149; shared components
  `email-templates.apx` (new), `lists.apx`, `breadcrumbs.apx`

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_82.zip` over COMMON with **Parsing Schema = XXCUS** and
**Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
A re-run changes nothing. No data is deleted.

## Tests
`apex/tests/r82_workflow_test.sql` (as XXFUSION) and `apex/tests/r82_workflow_ui.py`.
