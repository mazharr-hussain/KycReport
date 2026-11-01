# App Settings - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Application settings

- **Purpose:** the settings of the running application.
- **What it does:** lists and changes the APEX application settings.
- **Why:** settings change from the console, not in App Builder.

* **How it works:** reads and writes the running application's APEX settings.
* **How it's built:** *APEX:* application settings (`APEX_APP_SETTING`), interactive report. *Custom:* `XXFND_APP_SETTING_PKG`.

- **DB objects:** *Own:* Packages: XXFND\_APP\_SETTING\_PKG. *Uses:* XXFND\_APPLICATIONS, XXFND\_APPLICATION\_PKG.

* **Shared components:** App items: G\_ADMIN\_APP; Authorizations: page-manage, page-submit, page-view; Breadcrumb: breadcrumb; Page groups: features.
