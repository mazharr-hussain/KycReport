# Case Assignment

Feature of KYC Compliance Platform. It has no page or object of its own: it is the
privilege CASE_ASSIGNMENT.MANAGE (registered in `db/scripts/18h-register-with-common.sql`), checked by
XXCMP_CASE_PKG.CAN_ASSIGN in `features/cases`.

## Purpose
Who may give a KYC case to a Compliance officer.

## Usage
The privilege CASE_ASSIGNMENT - Manage enables Assign Case on the request (205) and case (211) screens.

## Benefit
Case allocation is controlled by role, not by who happens to hold the case.

