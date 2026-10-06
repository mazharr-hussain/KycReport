# Patch 28 – Ownership Tree tab, report conclusion and next steps (release 43)

Goes on top of any earlier release of app 134 (the import brings every database change with it).

## What changes
- **Owners and Officers** is back to how it was before release 42 (one level; Party, Role, Relationship,
  Ownership %, Start / End Date, Action).
- **Ownership Tree** (new, separate):
  - **Party screen:** a new *Ownership Tree* region: the whole tree (owners of owners, indented) with Country /
    Nationality, Incorporation / Birth Date, Registration / ID No., Document Expiry.
  - **Case screen:** a new section **Ownership Tree** after Party: the case's party and its tree, each row with that
    party's latest screening in the case (**Results, Conclusion, Source, Risk Level**) and the actions **Screen**,
    **Add Owner** (related company), **Edit**. The section is ticked when every party in the tree is screened.
- **Case → Risk Assessment:** new **Report Conclusion** and **Next Steps** (required: *Submit for Approval* asks for
  both). Shown in the case summary on Review and Submit.
- Fixed: after a dialog on the case, the owners' Edit links no longer disappear.

DB (in the supporting objects): `XXCMP_CASES.REPORT_CONCLUSION`, `NEXT_STEPS` (varchar2(4000));
`xxcmp_party_pkg.owners_json` as before and new `ownership_tree_json`; `xxcmp_case_pkg` section TREE
(lookup CASE_SECTION) and the submit check; `xxcmp_request_ui_pkg.case_summary_html`.

## Deploy – application import only
1. Export app 134 as a backup.
2. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_43.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: Yes**. APEX sees the existing tables and runs the **upgrade scripts**: every
   database change of releases up to 43 (including patches 25-27), idempotent, tables and data kept.
3. Make the SSO scheme current again if you use it.

No separate SQL script is needed. (`app/` holds the changed pages 0 and 211 and supporting objects 16b, 16e, 16i,
18e for reference.)

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- The 34 upgrade scripts run in their APEX order on the existing database: no errors, no invalid objects.
  (The command-line import used locally does not run supporting objects, so the App Builder step itself was not
  exercised; it runs these same scripts.)
- `apex validate` passes.
- Browser: case sections 1-8 with *3 Ownership Tree*; Party section shows the original Owners and Officers; the tree
  shows party ← holding (60 %) ← owner with screening results and Screen / Add Owner / Edit; party screen shows the
  tree without the case columns.
- `kyc_ui.py` 26/26 (now fills Report Conclusion and Next Steps), `party_ui.py` 23/23, `request_party_ui.py` 24/24.
