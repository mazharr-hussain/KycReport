
create or replace view xxfnd_document_categories_vl as
select c.category_code,
       c.application_code,
       nvl(t.category_name, c.category_name) category_name,
       nvl(t.description, c.description)     description,
       c.default_datatype_code,
       c.has_expiry_flag,
       c.max_age_days,
       c.enabled_flag,
       c.start_date_active,
       c.end_date_active
  from xxfnd_document_categories c
  left join xxfnd_document_categories_tl t
    on t.category_code = c.category_code
   and t.language_code = xxfnd_util_pkg.current_lang;
