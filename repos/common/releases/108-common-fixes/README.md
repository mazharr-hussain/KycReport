# COMMON 108 - Review fixes (COMMON independent of KYC, unused items removed)

Build: `releases/COMMON-Application-APEXlang_108.zip` (application version "Release 108"), on top of COMMON 107.
Built with `repos/common/build.sh --release 108`; checked with the APEXlang validation ("Validation successful").
No database was run (offline validation only).

**Order:** deploy KYC 101 first (it moves the party-details access rule into the KYC party package), then COMMON 108.

## What changes
| Item | Change |
|---|---|
| Unused items removed | LOV `DFF_COLUMNS`, authorization `ADMIN_APP` (app component), table `XXFND_TRANSMISSIONS` (no longer created; on an existing database it is dropped only while empty - script 41a) |
| Wrapper routines removed | `XXFND_UTIL_PKG.CREATE_WHO_TRIGGER` / `CREATE_ALL_WHO_TRIGGERS`, `XXFND_AUDIT_PKG.CREATE_AUDIT_TRIGGER` / `CREATE_CONFIG_AUDIT_TRIGGERS`, `XXFND_VPD_PKG.APPLY_POLICIES`: the install scripts call `XXFND_SCHEMA_PKG` directly |
| Shared LOVs | Page 116 Notification Delivery: 4 inline grid LOVs replaced with the shared LOVs `ENABLED_APPLICATIONS` and `NOTIFICATION_TEMPLATES` |
| COMMON independent of KYC | `XXFND_USER_PKG.AUTHORIZED`: the `PARTY_DETAILS_*` schemes and the dynamic `XXCMP_PARTY_PKG` call removed; `XXFND_ATTACH_PKG.PAGE_LIMITS`: no `'KYC'` fallback; seed script 17 no longer seeds the 13 KYC lookup types (KYC registers them through `XXFND_LOOKUP_PKG`, script 18h); the KYC-dependent tests moved to `repos/kyc/tests/common-usage/` |
| One object per file | `lists.apx`, `lovs.apx`, `authorizations.apx` split into one file per component under `shared-components/<kind>/` |
| Comments | KYC examples in `XXFND_DFF_PKG`, `XXFND_APPROVAL_PKG`, `XXFND_CONFIG_TABLES`, `XXFND_RFIS` made generic |

## Files
- `app/` page 116 and the two new LOVs
- `db/` + `run-release.sql`: the database files of this release, numbered in upgrade order (the same files as
  `db/deploy/upgrade/`), then a recompile of invalid objects

## Deploy
1. App Builder > Import `COMMON-Application-APEXlang_108.zip` over COMMON (135), Install Supporting Objects = Yes; or run
   `run-release.sql` as XXFUSION (SQLcl / SQL Developer / Database Actions F5). A re-run changes nothing.

## Live checks
- Page 116: the Application and Template columns list from the shared LOVs.
- In KYC as a requester: the contact person / owner dialogs of their own request's party still open (KYC 101 rule).
- `select count(*) from user_tables where table_name = 'XXFND_TRANSMISSIONS'` returns 0 (when it was empty).
