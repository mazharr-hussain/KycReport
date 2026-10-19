# Patch 116 - KYC 95: KYC on COMMON's sign-in and security model (6 items)

Build: `KYC-Compliance-Platform-APEXlang_95.zip` (application version "Release 95"). KYC only. Needs COMMON 100
(patch 115) installed first.

## What changes
1. **Sign-in through COMMON.** KYC subscribes to COMMON's authentication schemes (Oracle APEX Accounts - current - and
   the company account APEX_FA_IABWBN-DEV1_OAUTH, Switch in Session); it keeps no sign-in of its own. KYC's login page
   sends the user to COMMON's login page (`P9999_APP=KYC`); after the sign-in (password or company account) the user is
   on KYC's home page. One sign-in for COMMON and KYC (workspace session sharing).
2. **Administration menu (UI issue 10).** The menu entry opens the new page 100 Administration: KYC's own setup, the
   common functions IT lets KYC's administrators manage (opened in COMMON for KYC) and COMMON's shared setup, as cards
   (the same list as before).
3. **Security model (COMMON 96).** KYC registers its data objects on the Department dimension: KYC Requests
   (REQUESTING_DEPARTMENT, owner REQUESTER_USER_NAME) and **KYC Cases** - new column XXCMP_CASES.REQUESTING_DEPARTMENT
   (script 16x: added when missing, existing cases get their request's department; a new case copies it in
   XXCMP_CASE_PKG.OPEN_CASE). A role with access by values (e.g. Requesting Entity1 = Finance) sees only its
   departments' records; roles with all records are unchanged.
4. **Wording.** The message when a requester may raise requests for no department now names the requesting entity
   role and its data access values (message KYC_REQUEST_NO_ENTITY); Create Request help updated.
5. **Approval deadlines (COMMON 94).** The request approval task (Document Checklist Review) is due at the deadline of
   the current Approval Setup step (DUE_DAYS), else the task setting.
6. **Help.** Navigation bar entry Help: COMMON's help of the current page (COMMON page 174); it shows once COMMON's
   Help & Training is installed.

## Files
- `db/`: 16x-case-department.sql (new), 16s-case-pkg.sql, 16r-request-pkg.sql, 18e-kyc-requests-cases.sql,
  18h-register-with-common.sql, manifest.json
- `app/`: application.apx, pages p00100-administration.apx (new), p09999-login.apx, p00201-create-request.apx,
  shared-components authentications.apx, lists.apx, breadcrumbs.apx, task-definitions/DOC-CHECKLIST-REVIEW.apx

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_95.zip` over KYC (134), Install Supporting Objects: Yes.

## Tests
APEXlang validation passed. Not run (as agreed).
