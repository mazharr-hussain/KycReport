# Patch 43 – COMMON import page and ADMIN script fix (release 58)

## Why
- App Builder showed a blank Import Application page for the COMMON zip. COMMON was the only application that
  pre-set its parsing schema (XXFUSION) in `application.apx`; that setting is removed.
- The ADMIN move script failed in the SQL worksheet with PLS-00103 (end-of-file): it held `'begin ... end;'` strings,
  which the worksheet treats as the end of the statement. They are now `CALL` statements.

## Deploy
1. Import `COMMON-Application-APEXlang_58.zip` → on the Install step pick **Parsing Schema = XXFUSION** →
   Install Supporting Objects: Yes. (Left at XXCUS, the install only reports ORA-20901 with the fix.)
2. Existing KYC, once: as ADMIN run `admin/move-kyc-shared-data-to-xxfusion.sql` (Run Script, F5).
   It validates first; it must end with "Done: ... Now import KYC."
3. Import `KYC-Compliance-Platform-APEXlang_58.zip` over app 134, Install Supporting Objects: Yes.
