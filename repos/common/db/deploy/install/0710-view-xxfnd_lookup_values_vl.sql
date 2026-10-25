--------------------------------------------------------------------------------
-- 05_views.sql
-- Translation-resolved (_VL) views and working views used by the application.
-- Language comes from XXFND_UTIL_PKG.CURRENT_LANG (03_xxfnd_core_pkgs.sql),
-- so this file runs after it.
--------------------------------------------------------------------------------

create or replace view xxfnd_lookup_values_vl as
select v.lookup_type,
       v.lookup_code,
       nvl(t.meaning, v.meaning)          meaning,
       nvl(t.description, v.description)  description,
       v.tag,
       v.parent_lookup_type,
       v.parent_lookup_code,
       v.display_sequence,
       v.enabled_flag,
       v.start_date_active,
       v.end_date_active,
       case when v.enabled_flag = 'Y'
             and trunc(sysdate) between v.start_date_active and nvl(v.end_date_active, trunc(sysdate))
            then 'Y' else 'N' end        active_flag
  from xxfnd_lookup_values v
  left join xxfnd_lookup_values_tl t
    on t.lookup_type = v.lookup_type
   and t.lookup_code = v.lookup_code
   and t.language_code = xxfnd_util_pkg.current_lang;
