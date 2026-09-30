create or replace force editionable view xxcus.xxfnd_document_entities_vl (
    entity_name,
    application_code,
    user_entity_name,
    description,
    table_name,
    pk1_column,
    pk2_column,
    pk3_column,
    pk4_column,
    pk5_column,
    enabled_flag
) as
    select
        e.entity_name,
        e.application_code,
        nvl(t.user_entity_name, e.entity_name) user_entity_name,
        t.description,
        e.table_name,
        e.pk1_column,
        e.pk2_column,
        e.pk3_column,
        e.pk4_column,
        e.pk5_column,
        e.enabled_flag
    from
        xxfnd_document_entities    e
        left join xxfnd_document_entities_tl t on t.entity_name = e.entity_name
                                                  and t.language_code = xxfnd_util_pkg.current_lang;


-- sqlcl_snapshot {"hash":"810fb01df4a35faf38cb7905bdc6a9bd812c0c03","type":"VIEW","name":"XXFND_DOCUMENT_ENTITIES_VL","schemaName":"XXCUS","sxml":""}