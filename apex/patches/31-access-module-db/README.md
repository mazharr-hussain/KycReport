# Patch 31 – shared access module, database (release 46)

First step of the shared access module (users, applications, app-scoped roles) that later applications reuse.
Database only; the screens follow in the next patches.

## What changes
- **XXFND_APPLICATIONS** (new): one row per application; `APPLICATION_ID` = the APEX application ID, primary key,
  cannot be changed (trigger). Seeded: 134 / KYC / KYC Compliance Platform.
- **XXFND_USERS** (new): the users of all applications. `USER_TYPE` **SSO** = linked to an employee (signs in with
  the company account, no password) or **LOCAL** = no employee, Oracle APEX account (APEX keeps the password).
- **XXFND_ROLES.APPLICATION_ID**, **XXFND_FEATURES.APPLICATION_ID** (FK to XXFND_APPLICATIONS): roles and features
  belong to one application; existing ones = 134.
- **XXFND_USER_ROLES.USER_ID** (FK to XXFND_USERS): grants belong to the user. Every employee with a grant became an
  SSO user and the grants moved to it. Grants still made for an employee (current Users & Access screen) are
  given to the employee's user automatically (trigger XXFND_USER_ROLES_USER).
- `xxfnd_user_roles_v` reads the users; the login (e-mail or user name) is matched to the user first, then the
  employee. "KYC User" and "Administration Area" count only the privileges of the current application.
- **XXFND_USER_PKG**: `create_local_user` (creates the APEX account too), `reset_password`, `set_enabled`
  (locks / unlocks the APEX account), `employee_user` – for the access console (Users & Access – Manage).
- **Sign-in rule** (XXFND_AUTH_PKG): with application setting **LOGIN_TYPE_ENFORCED = Y**, SSO users can only sign
  in with the company account and LOCAL users only with user name / password. Default **N** (until SSO is live).

## Deploy – application import only
**App Builder → Import** `KYC-Compliance-Platform-APEXlang_46.zip` → **Replace Existing Application** 134 →
**Install Supporting Objects: Yes**. Make the SSO scheme current again if you use it.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- All 37 upgrade scripts in APEX order: no errors, no invalid objects; 6 employees with grants → 6 SSO users; no
  grant without a user, no role / feature without an application.
- In an APEX session as an administrator: local user created with its APEX account, locked / unlocked, password
  reset, role granted (visible in the roles view).
- `kyc_ui.py` 26/26, `party_ui.py` 23/23, `request_party_ui.py` 24/24; admin console test runs.
