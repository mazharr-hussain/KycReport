create or replace force editionable view xxcus.xxfnd_df_contexts_vl (
    descriptive_flexfield_code,
    context_code,
    context_name,
    description,
    global_flag,
    enabled_flag,
    protected_flag
) as
    select
        c.descriptive_flexfield_code,
        c.context_code,
        nvl(t.context_name, c.context_name) context_name,
        nvl(t.description, c.description)   description,
        c.global_flag,
        c.enabled_flag,
        c.protected_flag
    from
        xxfnd_df_contexts    c
        left join xxfnd_df_contexts_tl t on t.descriptive_flexfield_code = c.descriptive_flexfield_code
                                            and t.context_code = c.context_code
                                            and t.language_code = xxfnd_util_pkg.current_lang;


-- sqlcl_snapshot {"hash":"822db30dd38d35e82365bd2547ff758741de9374","type":"VIEW","name":"XXFND_DF_CONTEXTS_VL","schemaName":"XXCUS","sxml":""}