# Application Menu - requirements (COMMON)

Functional requirements of the component. Source of truth: this file (changed in the same PR as the code); the
application summary is `repos/common/docs/README.md`.

## Application menu

- **Purpose:** the navigation (side menu and top bar) of every application, managed in one place.
- **What it does:** lists every page of every application once, with its privilege, the menus it is in, the pages that link to it and where it is opened from. Shows and edits the menu of one application.
- **Why:** one place to manage all navigation; each entry shows only to users with the privilege of its page.

* **How it works:** every application registers its menu entries in COMMON; the side menu and top bar are built from that registry and show an entry only when the user holds its page's privilege.
* **How it's built:** *APEX:* interactive reports, dynamic lists, the APEX dictionary. *Custom:* menu registry tables, `XXFND_NAV_PKG`, page catalogue views.

- **DB objects:** *Own:* Tables: XXFND\_APP\_MENU\_ENTRIES, XXFND\_PAGE\_OPENS; Views: XXFND\_NAV\_MENU\_V, XXFND\_PAGE\_LINKS\_V, XXFND\_PAGE\_CATALOGUE\_V; Packages: XXFND\_NAV\_PKG. *Uses:* XXFND\_APPLICATIONS, XXFND\_APPLICATION\_PKG, XXFND\_FEATURES, XXFND\_FEATURE\_PAGES.

* **Shared components:** Authorizations: page-manage, page-submit, page-view; Breadcrumb: breadcrumb; Lists: administration, navigation-menu, navigation-bar; Page groups: administration.

## Menu group page (COMMON 111)

- **Purpose:** one page that opens any menu group of any application and shows what is in it.
- **What it does:** clicking a group in the side menu (or its breadcrumb level) opens page 100 for that group: the group's entries the user may open, as cards; a page opens it, a group opens its own group page. Without a group, page 100 shows the COMMON modules with their state. Works for every application's menu.
- **How it's built:** *APEX:* list region with the Cards template, breadcrumb. *Custom:* `XXFND_APPLICATION_PKG.MENU_URL` links a folder to page 100 (`P100_GROUP`); `XXFND_NAV_MENU_V` gives the entries of a group (ENTRY_CODE / PARENT_CODE) and marks the open group as current.

## Change - Menu group page, RFI lookups (COMMON 111)

- Clicking a menu group opens its group page (page 100): the group's entries the user may open, as cards. The breadcrumb's group level opens the same page. Works for every application's menu.
- `RFI_STATUS`, `RFI_RECIPIENT_TYPE` and `RFI_CATEGORY` are shared COMMON lookups.
- The `KYC_USER` scheme is retired; every application uses `APP_USER` (KYC must switch: COMMON-ISSUES C18).
- Fix: the release 109 install of `XXFND_SERVERS_V` failed in SQL Developer (a comment ending with `;`).
- Retention stays a placeholder.
