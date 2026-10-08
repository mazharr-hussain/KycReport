# Patch 54 – no install error on existing objects (release 69: COMMON and KYC)

## What changes
- **KYC install check:** App Builder decides between *install* and *upgrade* with the query under Supporting
  Objects > Upgrade. It looked for `XXFND_LOOKUP_TYPES` in XXCUS; the move to XXFUSION (release 54+) removed that
  table from XXCUS, so App Builder ran the install scripts on an existing KYC and script 04 failed with ORA-00955.
  It now looks for KYC's own table `XXCMP_PARTIES`. COMMON is unchanged (its table is in its own schema).
- **Database (00):** `XXFND_DDL_PKG` gains checked helpers: `CREATE_TABLE` (create only when missing),
  `ENSURE_INDEX`, `ENSURE_SEQUENCE`, `DROP_COLUMN`, `ADD_CONSTRAINT`, `DROP_CONSTRAINT`, `DROP_INDEX`, `RUN`.
- **Database (01-04):** every table is created with its indexes and comments only when it is missing; an existing
  table is left as it is (its later changes are made by the numbered scripts, each checked). No script fails with
  ORA-00955 any more, whichever way it is run.

## Deploy
1. COMMON: import `COMMON-Application-APEXlang_69.zip` over COMMON (import as XXCUS, Parsing Schema XXFUSION -
   see `apex/install/COMMON/INSTALL.md`), Install Supporting Objects: Yes.
2. KYC: import `KYC-Compliance-Platform-APEXlang_69.zip` over app 134 (Replace Existing Application), Install
   Supporting Objects: Yes. App Builder now runs the **upgrade**.

If you already used the workaround (detect query changed to `XXCMP_PARTIES` in App Builder), nothing else is
needed; the import of 69 carries the same query.
