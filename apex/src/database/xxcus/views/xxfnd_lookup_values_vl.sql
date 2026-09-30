create or replace force editionable view xxcus.xxfnd_lookup_values_vl (
    lookup_type,
    lookup_code,
    meaning,
    description,
    tag,
    parent_lookup_type,
    parent_lookup_code,
    display_sequence,
    enabled_flag,
    start_date_active,
    end_date_active,
    active_flag
) as
    select
        v.lookup_type,
        v.lookup_code,
        nvl(t.meaning, v.meaning)         meaning,
        nvl(t.description, v.description) description,
        v.tag,
        v.parent_lookup_type,
        v.parent_lookup_code,
        v.display_sequence,
        v.enabled_flag,
        v.start_date_active,
        v.end_date_active,
        case
            when v.enabled_flag = 'Y'
                 and trunc(sysdate) between v.start_date_active and nvl(v.end_date_active,
                                                                        trunc(sysdate)) then
                'Y'
            else
                'N'
        end                               active_flag
    from
        xxfnd_lookup_values    v
        left join xxfnd_lookup_values_tl t on t.lookup_type = v.lookup_type
                                              and t.lookup_code = v.lookup_code
                                              and t.language_code = xxfnd_util_pkg.current_lang;


-- sqlcl_snapshot {"hash":"e076b82371cb13c950261fc17c6c2cba426de801","type":"VIEW","name":"XXFND_LOOKUP_VALUES_VL","schemaName":"XXCUS","sxml":""}