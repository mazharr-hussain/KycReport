
create or replace package body xxfnd_nav_pkg as
    function nav_menu(p_menu_code in varchar2 default 'SIDE') return t_nav_rows pipelined is
        l_row t_nav_row;
    begin
        for r in (select lvl, label, target, is_current, image, image_attribute, image_alt, a01, a02, sort_path
                    from xxfnd_nav_menu_v where menu_code = upper(nvl(p_menu_code, 'SIDE'))) loop
            l_row.lvl             := r.lvl;
            l_row.label           := r.label;
            l_row.target          := r.target;
            l_row.is_current      := r.is_current;
            l_row.image           := r.image;
            l_row.image_attribute := r.image_attribute;
            l_row.image_alt       := r.image_alt;
            l_row.a01             := r.a01;
            l_row.a02             := r.a02;
            l_row.sort_path       := r.sort_path;
            pipe row (l_row);
        end loop;
        return;
    end nav_menu;

    procedure record_open(p_referrer in varchar2) is
        pragma autonomous_transaction;
        l_app  varchar2(255);
        l_page varchar2(255);
    begin
        if p_referrer is null then
            return;
        elsif regexp_like(p_referrer, '/r/[^/]+/[^/?#]+/[^/?#]+', 'i') then
            l_app  := upper(regexp_substr(p_referrer, '/r/[^/]+/([^/?#]+)/([^/?#]+)', 1, 1, 'i', 1));
            l_page := upper(regexp_substr(p_referrer, '/r/[^/]+/([^/?#]+)/([^/?#]+)', 1, 1, 'i', 2));
        else
            l_app  := upper(regexp_substr(p_referrer, 'f\?p=([^:&]+):([^:&]*)', 1, 1, 'i', 1));
            l_page := upper(regexp_substr(p_referrer, 'f\?p=([^:&]+):([^:&]*)', 1, 1, 'i', 2));
        end if;
        if l_app is null or l_page is null or l_app in (upper(v('APP_ALIAS')), v('APP_ID')) then
            return;
        end if;
        merge into xxfnd_page_opens t
        using (select substr(l_app, 1, 255) from_app_alias, substr(l_page, 1, 255) from_page,
                      to_number(v('APP_ID')) to_application_id, to_number(v('APP_PAGE_ID')) to_page_id
                 from dual) x
           on (t.from_app_alias = x.from_app_alias and t.from_page = x.from_page
               and t.to_application_id = x.to_application_id and t.to_page_id = x.to_page_id)
         when matched then update set t.open_count = t.open_count + 1, t.last_opened_date = systimestamp
         when not matched then insert (from_app_alias, from_page, to_application_id, to_page_id, open_count,
                                       first_opened_date, last_opened_date)
                               values (x.from_app_alias, x.from_page, x.to_application_id, x.to_page_id, 1,
                                       systimestamp, systimestamp);
        commit;
    exception
        when others then
            rollback;    -- the record is a statistic: the page opens all the same
    end record_open;
end xxfnd_nav_pkg;
/
