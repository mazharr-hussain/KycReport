# Patch 76 - Field Grid details, Metric Card home tiles, menu colours, display fixes (release 75)

## What changes
- New template component **KYC Field Grid** (`appTemplateComponent/fieldGrid`): label / value pairs grouped under a
  title, 3 columns (2 on tablets, 1 on phones), long values across the row, status badges, person names, links. Used by
  the request details (205, 206), the case summary (211), the party card (222) and the Global Page party summary.
- Home tiles are the theme's **Metric Card** template component (icon, number, title, link; zero and overdue tones).
- Section menu: done / warning / current colours on the Links List icons.
- Case screen: PEP flag shows Yes / No; next review date and conditions only when set; the findings grid does not
  select its first row; case history and approval history show person names.
- CSS: the old KPI tile styles removed.

## Files
- `app/KYC/pages/p00000-global-page.apx`
- `app/KYC/pages/p00001-home.apx`
- `app/KYC/pages/p00222-reassessment.apx`
- `app/KYC/shared-components/plugins/template-component/fieldGrid/plugin.apx`
- `app/KYC/shared-components/plugins/template-component/fieldGrid/custom-attributes.apx`
- `app/KYC/shared-components/plugins/template-component/fieldGrid/attribute-groups.apx`
- `app/KYC/shared-components/static-files/css/kyc-app.css`

Files shared with other release 75 parts are listed once, in the patch of their latest change.

## Tests
- `tests/r75_ui.py` (browser: layout and both assignment flows)

## Deploy (release 75, KYC only)
The release zip carries both patches of release 75 (76-77); deploy it once, not patch by patch. COMMON is not changed
(release 74 COMMON must already be installed).
1. KYC: import `KYC-Compliance-Platform-APEXlang_75.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   Or run `KYC-Compliance-Platform-SQL-Install_75.sql` as ADMIN in SQL Developer Web (see `install/KYC/INSTALL.md`).
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
