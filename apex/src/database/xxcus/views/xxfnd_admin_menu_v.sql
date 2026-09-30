create or replace force editionable view xxcus.xxfnd_admin_menu_v (
    feature_code,
    feature_name,
    feature_group,
    display_sequence,
    description,
    icon_css,
    home_page_id
) as
    select
        f.feature_code,
        f.feature_name,
        f.feature_group,
        f.display_sequence,
        f.description,
        nvl(f.icon_css, 'fa-cog') as icon_css,
        f.home_page_id
    from
        xxfnd_features f
    where
            f.admin_flag = 'Y'
        and f.enabled_flag = 'Y'
        and f.home_page_id is not null
        and xxfnd_privilege_pkg.has_privilege_yn(f.feature_code, 'VIEW') = 'Y';


-- sqlcl_snapshot {"hash":"f5b200b966538018cd12dfccc1c1281c3c4d94ba","type":"VIEW","name":"XXFND_ADMIN_MENU_V","schemaName":"XXCUS","sxml":""}