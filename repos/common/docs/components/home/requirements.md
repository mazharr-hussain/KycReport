# Home - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Home

- **Purpose:** the landing page of COMMON.
- **What it does:** opens after sign-in, with KPIs and a start point to the setup screens the user may open.
- **Why:** one entry point for IT and delegated administrators.

* **How it works:** shows the user's KPIs and the setup screens their privileges open.
* **How it's built:** *APEX:* page with KPI regions, human task API for task counts. *Custom:* none.

- **DB objects:** *Own:* none. *Uses:* XXFND\_NOTIFY\_PKG, XXFND\_USER\_PKG, XXFND\_WORKFLOW\_PKG.

* **Shared components:** App items: G\_RETURN\_APP, G\_USER\_HOME\_URL; Authorizations: signed-in-user; Breadcrumb: breadcrumb; Lists: module-cards.
