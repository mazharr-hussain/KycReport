
create or replace view xxfnd_df_contexts_vl as
select c.descriptive_flexfield_code,
       c.context_code,
       nvl(t.context_name, c.context_name) context_name,
       nvl(t.description, c.description)   description,
       c.global_flag,
       c.enabled_flag,
       c.protected_flag
  from xxfnd_df_contexts c
  left join xxfnd_df_contexts_tl t
    on t.descriptive_flexfield_code = c.descriptive_flexfield_code
   and t.context_code = c.context_code
   and t.language_code = xxfnd_util_pkg.current_lang;
