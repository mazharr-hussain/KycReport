# Patch 07 – Request stuck at "Processing" (new party check constraint)

Goes on top of patch 06 (release 21). Database only: no pages change and no import is needed.

## Cause
REQ-000001 started on workflow version 1.0. Its **Evaluate intake** step failed with
`ORA-02290: check constraint (XXCUS.XXCMP_PARTIES_CK4) violated`, so the request stayed at *Processing*.
The request was saved by an older release, which kept organisation fields (registration number, entity type,
incorporation date) and individual fields (date of birth, nationality) together. When the new party was created
from the request, the party table refused the mix: an individual can't have organisation fields, and an
organisation can't have individual fields. Requests saved since release 17 keep only the fields of their type. Your
newer request completed normally on version 1.2.

## Fix
`xxcmp_request_pkg.new_party` copies only the fields of the party type (organisation or individual).

## Deploy from the APEX screens
1. **SQL Workshop → SQL Scripts → Upload** `07-db-request-party-type.sql` → **Run**. The last result must show
   `XXCMP_REQUEST_PKG` package and package body **VALID**.
2. Restart REQ-000001: as an administrator, open **Workflows** (Administration, page 44) → the KYC Request workflow of
   REQ-000001 (state *Faulted*) → **Retry** (page 45). *Evaluate intake* runs again, and the request moves on.

`app/supporting-objects/...` holds the same change for future installs and upgrades (release 22). You only need it if
you install from the release zip.

## Tested (local Oracle 26ai + APEX 26.1)
- An individual's request that also carries organisation fields: the old code fails with ORA-02290, and the fixed
  code creates the individual party without them.
- `request_party_test.sql` 27/27.
