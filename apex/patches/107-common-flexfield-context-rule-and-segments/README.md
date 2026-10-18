# Patch 107 - COMMON 92: flexfield context rule and segment definition (UI issues 6, 7)

Build: `COMMON-Application-APEXlang_92.zip` (application version "Release 92"). COMMON only; KYC is not changed.
Install COMMON 91 (patch 105) first.

## What changes
1. **Descriptive Flexfield (153) - fixed values read-only (issue 6).** Primary Key Column (once registered) and Context
   Column (always ATTRIBUTE_CATEGORY) are shown, not chosen.
2. **Context rule instead of "Derive Context From Column" (issue 6).** As in Fusion / EBS, the context
   (ATTRIBUTE_CATEGORY) is filled automatically on save from the flexfield's rule:
   - Global - global segments (and the default context);
   - By attribute of the record - e.g. PARTY_TYPE, or COUNTRY (Context Attribute);
   - By function - a function you name, `f(p_table_name, p_pk_value) return varchar2`, returns the context (any logic);
   - Chosen by the user - picked from a list (was the "User Chooses Context" switch).
   Existing flexfields keep their behaviour (a reference column becomes "By attribute", the user switch "Chosen by the
   user", otherwise "Global").
3. **Segments grid (issue 7).**
   - Column: the flexfield table's ATTRIBUTE columns, each showing the segments already using it (the old list read
     another table's columns, so it was empty).
   - Display Name (the prompt) and API Name (new; defaults to the segment code in lower case).
   - Validation: None (by format), Lookup or Value set; a lookup type is offered directly and its value set
     (XXFND_LK_<TYPE>) is created when the segment is saved.
   - Sequence may be left empty: the next of the context, by 10.

## Database
- `10a-flexfield-context-rule.sql` (new, install 96 / upgrade 56): checked steps - XXFND_DF_FLEXFIELDS.CONTEXT_RULE_TYPE,
  CONTEXT_RULE_FUNCTION, check constraint CK4; XXFND_DF_SEGMENTS.API_NAME; the rule and API name of existing rows.
- `10`, `11`: XXFND_DFF_PKG - the rule in RESOLVE_CONTEXT, REGISTER_FLEXFIELD (new optional p_context_rule_type /
  p_context_rule_function), LOOKUP_VALUE_SET (new).
- `12`: triggers - the rule keeps the related fields consistent; segment API name, sequence and lookup validation.
A re-run changes nothing.

## Files
- `db/10a-flexfield-context-rule.sql`, `db/10-flexfield-runtime-part-1-of-2.sql`, `db/11-flexfield-runtime-part-2-of-2.sql`,
  `db/12-flexfield-setup.sql`
- `app/application.apx` (Release 92), `app/pages/p00153-descriptive-flexfield.apx`
- `tests/r92_flexfield_test.sql` (new, as XXFUSION), `tests/r92_flexfield_ui.py` (new, browser)

## Deploy
App Builder > Import `COMMON-Application-APEXlang_92.zip` over COMMON (135), Install Supporting Objects: Yes (as for
patch 105).

## Tests (local database, COMMON 92)
- Install of 10a, 10, 11, 12 over COMMON 91, then a re-run of 10a: no error, no invalid object. The parties flexfield
  became "By attribute" (PARTY_TYPE), the other two "Global".
- `r92_flexfield_test.sql`: 6/6 pass (migrated rule; Global / Function / User rules on the trigger; lookup validation
  creates its value set; API name and sequence defaults).
- `r92_flexfield_ui.py` as ADMIN: 7/7 pass (read-only columns, rule with attribute / function shown by the rule, grid
  headings).
- Nothing else in COMMON was changed or re-tested.
