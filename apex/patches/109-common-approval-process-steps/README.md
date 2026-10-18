# Patch 109 - COMMON 94: workflow - process, rules, user-level approvers, step deadlines, delegation (UI issue 8)

Build: `COMMON-Application-APEXlang_94.zip` (application version "Release 94"). COMMON only; KYC is not changed.
Install COMMON 93 (patch 108) first.

## What changes (as agreed: fixed user-level approval now, the HCM-based approver types as placeholders)
1. **Approver types (Approval Setup > rule (149), Approvers):** A user (first in the list, the one in use), a role, the
   requester - and, listed as *not available yet*: Position, Manager, Supervisor hierarchy, Position hierarchy, Area of
   responsibility, Query. Saving a placeholder type is refused with a message (ORA-20536): its resolver comes with the
   HCM tables. A rule that has one is also refused when an approval starts.
2. **Deadline per step (new column "Deadline (days)"):** a step may have its own deadline; empty = the process deadline
   of Deadlines and Escalation. The step's deadline is copied to the transaction when the approval starts
   (XXFND_APPROVAL_RULE_PKG.STEP_DUE_DATE), and the RFI tasks use it (XXFND_RFI_PKG.TASK_DUE_DATE).
3. **The engine, step by step:** the process's rule that applies (by priority and conditions) -> the step's approver
   (a user) -> the approver's active delegation for the process (vacation rule, XXFND_WF_DELEGATIONS, already applied by
   every task) -> the step / process deadline.
4. **Process screen (Workflow Setup > Process Catalogue, 147): "Approval Path per Process"** - every process with its
   rules (by priority), their steps in order, the approver of each step, its deadline and the approver's delegation
   today; the rule opens Approval Setup.

## Database
- `15d-approval-setup.sql`: checked steps - XXFND_APPROVAL_RULE_STEPS.APPROVER_VALUE (setting of the placeholder types),
  DUE_DAYS; XXFND_APPROVAL_TXN_STEPS.DUE_DAYS; constraints CK1/CK2 replaced by CK3 (types) / CK4 / CK5 (due days > 0);
  XXFND_APPROVAL_RULE_PKG: APPROVER_TYPE_AVAILABLE, STEP_DUE_DATE, placeholder check in APPROVAL_ERROR, labels; trigger
  XXFND_APPROVAL_RULE_STEPS_TYPE.
- `15c-rfi-workflow.sql`: TASK_DUE_DATE uses the step deadline.
A re-run changes nothing.

## Not in this release (placeholders, as agreed)
The HCM tables (one per Fusion HCM resource) and the resolvers of the position / manager / hierarchy / AOR / query
approver types. KYC's own task definitions still take the process deadline; they can use STEP_DUE_DATE when KYC is
changed.

## Files
- `db/15d-approval-setup.sql`, `db/15c-rfi-workflow.sql`
- `app/application.apx` (Release 94), `app/pages/p00147-process-catalogue.apx`, `app/pages/p00149-approval-rule.apx`
- `tests/r94_approval_test.sql` (new, as XXFUSION), `tests/r94_process_ui.py` (new, browser)

## Deploy
App Builder > Import `COMMON-Application-APEXlang_94.zip` over COMMON (135), Install Supporting Objects: Yes.

## Tests (local database, COMMON 94)
- 15d, 15c, then 15d again over COMMON 93: no error, no invalid object.
- `r94_approval_test.sql`: 4/4 pass - placeholder types not available; saving one refused (-20536); an approval on a
  user step routes to that user; the step deadline (3 days) is the step's due date.
- `r94_process_ui.py` as ADMIN: 3/3 pass - the Process Catalogue shows Approval Path per Process with the KYC and COMMON
  processes, steps, approvers, deadlines and delegations.
- Nothing else in COMMON was changed or re-tested.
