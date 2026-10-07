# Patch 46 – COMMON security screens (release 62, COMMON only)

## What changes
Copied from KYC into COMMON (same page numbers), working for the application selected on the Administration pages:
- Employees and Access (103, 104): an employee's role grid shows and grants only the roles of the selected application.
- Roles (105, 106): only that application's roles; a new role belongs to it.
- Segregation of Duties (107, 108), Data Security (180, 181): rules of that application's roles.
- Privileges (182), Delegations (114, 115).
- Lists of values: roles (selected application only), privileges (that application's features and the admin features),
  employees, employee source, SoD scope, task definitions. Breadcrumbs.
- New test apex/tests/admin_scope_test.sql (database scope) and apex/tests/common_admin_ui.py (pages).

## Verified locally
Validation OK; ADMIN opens all 12 pages; a user without an admin role is refused; scope test: an application sees its
rows and the shared rows, changes only its own rows, new rows belong to it. Database scripts unchanged since 61.

## Deploy
Import COMMON-Application-APEXlang_62.zip over COMMON (Parsing Schema XXFUSION), Install Supporting Objects: Yes.
