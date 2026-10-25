
-- Admin console entries the current user may open (VIEW privilege on the feature).
create or replace view xxfnd_admin_menu_v as
select f.feature_code,
       f.feature_name,
       f.feature_group,
       f.display_sequence,
       f.description,
       nvl(f.icon_css, 'fa-cog') as icon_css,
       f.home_page_id
  from xxfnd_features f
 where f.admin_flag   = 'Y'
   and f.enabled_flag = 'Y'
   and f.home_page_id is not null
   and xxfnd_privilege_pkg.has_privilege_yn(f.feature_code, 'VIEW') = 'Y';
