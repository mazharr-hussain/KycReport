# Give Feedback - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Give feedback

- **Purpose:** anyone gives feedback on the page they are on, in any application.
- **What it does:** one feedback form, opened from each application's navigation bar.
- **Why:** one feedback form for all applications.

* **How it works:** the navigation bar link passes the application and page; the feedback is stored with them.
* **How it's built:** *APEX:* modal page, feedback storage. *Custom:* none.

- **DB objects:** *Own:* none. *Uses:* XXFND\_APPLICATIONS, XXFND\_APPLICATION\_PKG.

* **Shared components:** Authorizations: signed-in-user; Breadcrumb: breadcrumb; Lists: administration; Page groups: administration.
