# Patch 101 - COMMON: Data Model for every application (release 89, COMMON only)

Build: `COMMON-Application-APEXlang_89.zip` (application version "Release 89").

## What changes
- **Data Model** (Platform menu, new feature DATA_MODEL with View and Manage; Common Administrator at install) shows the
  database objects of every registered application, read live from the database dictionary. It always matches what is
  installed after each upgrade.
  - **Data Model (175):** choose the application. It lists the application's objects (tables, views, packages, types,
    sequences, triggers) in an Interactive Report, with each object's group, status, dates and comment. Here you also set
    the application's **object prefix** (Manage): only objects whose name starts with it belong to the application.
    COMMON's prefix is `XXFND_`.
  - **Database Object (176):** one object. It shows its columns (type, null, default, keys, comment), constraints
    (with the table each foreign key refers to), indexes (function-based ones with their expression), triggers, data
    security policies, procedures and functions with their parameters, type attributes, grants, and the objects it uses
    and is used by. Every object name opens that object.
  - **Data Model Diagram (177):** the entity-relationship diagram with key columns only (primary, foreign, unique,
    indexed) and the foreign keys. You can view the whole application, one group (for COMMON, its six modules), or one
    table with the tables it refers to and the tables that refer to it.
- **Who sees what:**
  - IT sees every application.
  - An application's administrators see only their own application. They open it from their application's menu (the
    new menu entry every application gets) once IT lets the application manage Data Model.
  - The dictionary views are never granted to an application.
- **Groups:** an application may group its tables for the diagram with `XXFND_DATA_MODEL_PKG.REGISTER_TABLE_GROUP`.
  Deleting an application removes its prefix and groups.

## Files
- `db/`:
  - `33-data-model.sql` (new)
  - `09d-application-pkg.sql`: the delete list
  - `19c-share-with-applications.sql`: the Data Model views stay in COMMON
  - `admin/grant-dictionary-to-xxfusion.sql` (new, run by ADMIN)
  - `manifest.json`
- `app/`:
  - `application.apx` (Release 89)
  - pages 175, 176 and 177 (new)
  - breadcrumbs
  - static file `mermaid/mermaid.min.js` (Mermaid 10.9.1, draws the diagram) and `static-files.apx`

## Deploy (COMMON only)
1. App Builder > Import `COMMON-Application-APEXlang_89.zip` over COMMON with **Parsing Schema = XXCUS** and **Install
   Supporting Objects: No**.
2. Go to Edit Application Definition > Security > Parsing Schema, set it to **XXFUSION** and apply.
3. Run Utilities > Supporting Objects > **Install Supporting Objects**. This runs the upgrade; data is kept and a re-run
   changes nothing.
4. As **ADMIN** (Database Actions > SQL), run `db/admin/grant-dictionary-to-xxfusion.sql`. On Autonomous Database, if it
   is refused, run `grant select any dictionary to xxfusion;` instead.
5. Run **Install Supporting Objects** once more, so the Data Model reads the full dictionary. Until then the pages show
   COMMON's own objects only and say so.
6. In Data Model, set the object prefix of each application whose schema it shares (KYC: `XXCMP_`).

## Tests
- New tests:
  - `tests/r89_data_model_apps.sql` (as XXCUS, once: two small tables of the test application R86TEST)
  - `tests/r89_data_model_test.sql` (as XXFUSION: 25 checks, 22 without the dictionary grants)
  - `tests/r89_data_model_ui.py` (browser, as IT: menu, catalogue, object page, diagram)
- Install cycle (COMMON on its own), all with 0 errors:
  - fresh install without the dictionary grants, and its re-run
  - upgrade from release 88, and its re-run
  - re-run after the grants (the views switch to the DBA_ dictionary)
- All COMMON DB tests (r78-r89, admin_scope) pass on the fresh and the upgraded database, and the browser test passes.
- `r73_common_test.sql` needs KYC installed, as before.
- Not tested in the browser: an application's own administrator opening Data Model from their application. The
  visibility rule behind it (`APP_VISIBLE`) is the same one COMMON's other screens use.
