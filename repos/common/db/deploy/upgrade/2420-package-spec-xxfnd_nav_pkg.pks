
-- the menu for the navigation lists of every application: the view reads APEX's metadata (not grantable on), the
-- applications run this function (EXECUTE)
create or replace package xxfnd_nav_pkg authid definer as
    type t_nav_row is record (
        lvl             number,
        label           varchar2(4000),
        target          varchar2(4000),
        is_current      varchar2(3),
        image           varchar2(255),
        image_attribute varchar2(255),
        image_alt       varchar2(255),
        a01             varchar2(4000),
        a02             varchar2(4000),
        sort_path       varchar2(4000));
    type t_nav_rows is table of t_nav_row;
    -- Release 104: the navigation menu of the running page for the signed-in user (XXFND_NAV_MENU_V), for an APEX
    -- list: select lvl, label, target, is_current, image, image_attribute, image_alt
    --         from table(xxfnd_nav_pkg.nav_menu) order by sort_path
    -- Release 105: P_MENU_CODE SIDE (navigation menu), TOP_BAR (navigation bar; A01 = badge, A02 = class) or ADMIN.
    function nav_menu(p_menu_code in varchar2 default 'SIDE') return t_nav_rows pipelined;
    -- Release 106: a COMMON page was opened from another application's page (P_REFERRER: the browser's referrer URL,
    -- friendly /r/<workspace>/<app>/<page> or f?p=APP:PAGE): counted in XXFND_PAGE_OPENS (Opened From). Nothing for
    -- a page of the same application or an unknown referrer; never fails the page.
    procedure record_open(p_referrer in varchar2);
end xxfnd_nav_pkg;
/
