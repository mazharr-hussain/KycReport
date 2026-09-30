create or replace force editionable view xxcus.xxfnd_df_segments_vl (
    descriptive_flexfield_code,
    context_code,
    global_flag,
    segment_code,
    column_name,
    sequence_number,
    prompt,
    help_text,
    value_set_code,
    validation_type,
    format_type,
    maximum_size,
    required_flag,
    default_type,
    default_value,
    read_only_flag,
    display_flag,
    enabled_flag
) as
    select
        s.descriptive_flexfield_code,
        s.context_code,
        c.global_flag,
        s.segment_code,
        s.column_name,
        s.sequence_number,
        nvl(t.prompt, s.prompt)       prompt,
        nvl(t.help_text, s.help_text) help_text,
        s.value_set_code,
        vs.validation_type,
        vs.format_type,
        vs.maximum_size,
        s.required_flag,
        s.default_type,
        s.default_value,
        s.read_only_flag,
        s.display_flag,
        s.enabled_flag
    from
             xxfnd_df_segments s
        join xxfnd_df_contexts    c on c.descriptive_flexfield_code = s.descriptive_flexfield_code
                                    and c.context_code = s.context_code
        join xxfnd_value_sets     vs on vs.value_set_code = s.value_set_code
        left join xxfnd_df_segments_tl t on t.descriptive_flexfield_code = s.descriptive_flexfield_code
                                            and t.context_code = s.context_code
                                            and t.segment_code = s.segment_code
                                            and t.language_code = xxfnd_util_pkg.current_lang;


-- sqlcl_snapshot {"hash":"2369d63374ab2acebb2140626230ab7c38a49ce8","type":"VIEW","name":"XXFND_DF_SEGMENTS_VL","schemaName":"XXCUS","sxml":""}