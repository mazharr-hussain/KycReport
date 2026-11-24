
-- release 106: every page of every registered application, one row per page (its owner application), with who uses
-- it: the menus it is in (its owner's, and for a COMMON page every application whose menu has it), the pages that link
-- to it (XXFND_PAGE_LINKS_V) and the pages users opened it from (XXFND_PAGE_OPENS). COMMON only (APEX metadata).
-- I-089 (#258): the links (a scan of five APEX dictionary views) are read once per query (MATERIALIZE) and matched to
-- the pages with one join and GROUP BY - not two sub-queries per page row, which timed out page 169. Same columns and
-- the same values as before.
create or replace view xxfnd_page_catalogue_v as
with apps as (
    select /*+ MATERIALIZE */ x.application_code, x.application_name, a.application_id, upper(a.alias) as app_alias
      from xxfnd_applications x
      join apex_applications a on upper(a.alias) = upper(x.apex_app_alias)
     where a.workspace = (select max(c.workspace) from apex_applications c where upper(c.alias) = 'COMMON')),
pages as (
    select /*+ MATERIALIZE */ ap.application_code, ap.application_name, ap.application_id, ap.app_alias,
           p.page_id, p.page_name, upper(p.page_alias) as page_alias, p.page_mode
      from apps ap
      join apex_application_pages p on p.application_id = ap.application_id
     where p.page_id > 0),
links as (
    select /*+ MATERIALIZE */ l.from_application_id, l.from_page_id, l.link_source,
           case when l.target_app is null or substr(l.target_app, 1, 1) = chr(38) then l.from_application_id
                when regexp_like(l.target_app, '^[0-9]+$') then to_number(l.target_app)
                else (select max(ap.application_id) from apps ap where ap.app_alias = upper(l.target_app))
           end as target_application_id,
           upper(l.target_page) as target_page
      from xxfnd_page_links_v l),
-- the links to each page: the text of Linked From (the page's own links to itself left out) and whether another
-- application links to it
page_links as (
    select pt.application_id, pt.page_id,
           listagg(distinct case when not (lk.from_application_id = pt.application_id
                                           and nvl(lk.from_page_id, -1) = pt.page_id)
                                 then nvl(fa.application_code, to_char(lk.from_application_id))
                                      || nvl2(lk.from_page_id, ' ' || lk.from_page_id, '') || ' (' || lk.link_source || ')'
                            end, ', ' on overflow truncate)
                   within group (order by case when not (lk.from_application_id = pt.application_id
                                                         and nvl(lk.from_page_id, -1) = pt.page_id)
                                               then nvl(fa.application_code, to_char(lk.from_application_id))
                                                    || nvl2(lk.from_page_id, ' ' || lk.from_page_id, '') || ' (' || lk.link_source || ')'
                                          end) as linked_from,
           max(case when lk.from_application_id <> pt.application_id then 'Y' end) as other_app_link
      from pages pt
      join links lk on lk.target_application_id = pt.application_id
                   and (lk.target_page = to_char(pt.page_id) or lk.target_page = pt.page_alias)
      left join apps fa on fa.application_id = lk.from_application_id
     group by pt.application_id, pt.page_id),
-- a COMMON page in other applications' menus
common_menus as (
    select e.page_id,
           listagg(distinct e.application_code, ', ') within group (order by e.application_code) as in_menus_of
      from xxfnd_app_menu_entries e
     where e.target_type = 'COMMON_PAGE' and e.application_code <> 'COMMON'
     group by e.page_id),
-- the pages users opened each page from
page_opens as (
    select o.to_application_id, o.to_page_id,
           listagg(o.from_app_alias || ' ' || o.from_page || ' (' || o.open_count || 'x, last '
                   || to_char(o.last_opened_date, 'DD-MON-YYYY') || ')', ', ' on overflow truncate)
               within group (order by o.last_opened_date desc) as opened_from
      from xxfnd_page_opens o
     group by o.to_application_id, o.to_page_id)
select p.application_code,
       p.application_name,
       p.application_id,
       p.page_id,
       p.page_name,
       p.page_mode,
       fp.feature_code,
       f.feature_name,
       case when exists (select 1 from xxfnd_app_menu_entries e
                          where e.application_code = p.application_code and e.page_id = p.page_id
                            and (e.target_type in ('APP_PAGE', 'ADMIN_PAGE')
                                 or (e.target_type = 'COMMON_PAGE' and p.application_code = 'COMMON')))
            then 'Y' else 'N' end as in_own_menu,
       case when p.application_code = 'COMMON' then cm.in_menus_of end as in_menus_of,
       pl.linked_from,
       po.opened_from,
       case when (p.application_code = 'COMMON' and cm.in_menus_of is not null)
              or pl.other_app_link = 'Y'
              or po.opened_from is not null
            then 'Y' else 'N' end as used_by_other_apps
  from pages p
  left join page_links pl on pl.application_id = p.application_id and pl.page_id = p.page_id
  left join common_menus cm on cm.page_id = p.page_id
  left join page_opens po on po.to_application_id = p.application_id and po.to_page_id = p.page_id
  left join xxfnd_feature_pages fp on upper(fp.app_alias) = p.app_alias and fp.page_id = p.page_id
  left join xxfnd_features f on f.feature_code = fp.feature_code;
