create or replace force editionable view xxcus.xxfnd_document_categories_vl (
    category_code,
    application_code,
    category_name,
    description,
    default_datatype_code,
    has_expiry_flag,
    max_age_days,
    enabled_flag,
    start_date_active,
    end_date_active
) as
    select
        c.category_code,
        c.application_code,
        nvl(t.category_name, c.category_name) category_name,
        nvl(t.description, c.description)     description,
        c.default_datatype_code,
        c.has_expiry_flag,
        c.max_age_days,
        c.enabled_flag,
        c.start_date_active,
        c.end_date_active
    from
        xxfnd_document_categories    c
        left join xxfnd_document_categories_tl t on t.category_code = c.category_code
                                                    and t.language_code = xxfnd_util_pkg.current_lang;


-- sqlcl_snapshot {"hash":"23b98a7889783bb7b73fd6cb7e44ff6f722a5131","type":"VIEW","name":"XXFND_DOCUMENT_CATEGORIES_VL","schemaName":"XXCUS","sxml":""}