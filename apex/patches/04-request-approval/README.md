# Patch 04 – Request approval on the request page

Goes on top of patch 03 (release 18). It changes one page: **KYC Request (205)**. There are no database changes.

## Why there were no Approve / Reject buttons
The decision buttons are only for the Compliance approver (holders of the Document Checklist Review task:
Compliance Officer, Manager and Head). They used to appear only when the request was opened **from My Tasks**. Opened from KYC Requests, even an approver saw no buttons, and nobody could see who the request was waiting on. The **requester never gets these buttons**: nobody approves their own request.

## What changes
- **Approval region** (everyone who can open the request): each approval step, its status, **who it is with**
  (the assignee, or the people who can take it), the outcome, dates and who decided.
- **Approver opening the request from KYC Requests** now gets the decision directly: *Approve – Open Case*,
  *Reject Request*, and the new **Request Information**.
- **Request Information**: the approver types the question in Comment. The task goes to the requester, who answers in
  My Tasks, and then it comes back to the approver.
- FYI: APEX tasks have no FYI recipients. Comments and Request Information are recorded on the task and shown in
  My Tasks → task details.

## Deploy
App Builder → Import `KYC-Compliance-Platform-APEXlang_19.zip` → **Replace Existing Application** (same ID).
Answer **No** to *Install Supporting Objects*. Or copy `app/pages/p00205-kyc-request.apx` into the source and use `apex import`.

## Tested (local)
`request_approval_ui.py` 5/5, `request_party_ui.py` 21/21, `kyc_ui.py` 17/17, `apex validate`.
