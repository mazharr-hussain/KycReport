# Patch 22 – identity-domain user names (release 37)

Goes on top of patch 21 (release 36, app ID 134).

## What changes
- **Employees** keep three identifiers: `USER_NAME` = the Fusion / identity-domain user name (what single sign-on
  returns), `EMAIL_ADDRESS` = the work e-mail, and the new `FUSION_USER_ID` = the Fusion user account id. The Employee
  page shows Fusion User ID.
- **HCM sync** (automation Fusion HCM sync): after the workers, it reads the Fusion user accounts
  (`/hcmRestApi/resources/11.13.18.05/userAccounts`, Username and UserId by PersonId) and sets each employee's user
  name and Fusion user id. A worker without a user account keeps the e-mail as user name. The workers sync no longer
  overwrites the user name with the e-mail.
- **Rename:** when an employee's user name changes (sync or a LOCAL edit), every stored reference moves to the new
  name: requester, assignee, approver, decided by, RFI recipient, delegations, approval-path users, the WHO columns
  of all tables, and the potential owners of open workflow tasks (assigned tasks are delegated to the new name). Row
  dates and versions are kept; closed cases accept the rename. The audit log keeps the old name.
- **Sign-in:** every scheme runs `xxfnd_security_pkg.map_login_user` after authentication.
  - Oracle Database / APEX Accounts: the login page asks for the **Email**; APP_USER becomes the employee's user name.
  - OCI IAM Identity Domain (SSO): the identity-domain user name (`#sub#`) is the user name.
- Known limit: the *initiator* of a workflow started before the rename keeps the old name (APEX has no API to change
  it); the requester's own actions on those older requests still work by role.

## Deploy
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `22-db-idcs-user-names.sql` → **Run**. At the end: *no rows* invalid
   objects. Idempotent. (It regenerates the WHO triggers of all tables.)
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_37.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**. Make the SSO scheme current again.
4. Run the automation **Fusion HCM sync** once (Shared Components → Automations): user names switch to the
   identity-domain names and all records follow.
5. Database / APEX Accounts users: their account name is their e-mail; type the e-mail on the login page.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- Rename REQ2 and OFFICER1 and back: requests (requester, created / updated by) and all 64 open tasks of OFFICER1
  (29 assigned, delegated) move to the new name and back; no invalid objects.
- Employee REQ1 renamed to REQ1.IDCS with e-mail = the APEX account name: signing in as REQ1 gives APP_USER
  REQ1.IDCS, who sees their 51 requests; login label "Email".
- `request_party_ui.py` 24/24; `apex validate` passes.
- The Fusion userAccounts call needs a real Fusion pod; not tested locally.
