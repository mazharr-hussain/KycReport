
create or replace view xxfnd_document_entities_vl as
select e.entity_name,
       e.application_code,
       nvl(t.user_entity_name, e.entity_name) user_entity_name,
       t.description,
       e.table_name,
       e.pk1_column, e.pk2_column, e.pk3_column, e.pk4_column, e.pk5_column,
       e.enabled_flag
  from xxfnd_document_entities e
  left join xxfnd_document_entities_tl t
    on t.entity_name = e.entity_name
   and t.language_code = xxfnd_util_pkg.current_lang;
