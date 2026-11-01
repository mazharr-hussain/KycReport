# Optional Features - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Optional features

- **Purpose:** switch optional parts of an application on or off.
- **What it does:** includes or excludes the application's build options named "Feature - ...".
- **Why:** parts of an application change without a new release.

* **How it works:** flips the application's "Feature - ..." build options on or off.
* **How it's built:** *APEX:* build options (`APEX_UTIL.SET_BUILD_OPTION_STATUS`), interactive report. *Custom:* none.

- **DB objects:** *Own:* none. *Uses:* XXFND\_APPLICATIONS, XXFND\_APPLICATION\_PKG, XXFND\_APP\_SETTING\_PKG.

* **Shared components:** App items: G\_ADMIN\_APP; Authorizations: page-manage, page-submit, page-view; Breadcrumb: breadcrumb; Page groups: features.
