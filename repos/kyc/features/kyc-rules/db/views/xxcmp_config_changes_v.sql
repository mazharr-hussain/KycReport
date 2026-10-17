
--------------------------------------------------------------------------------
-- release 48: the view of the pending changes of the KYC configuration tables (answer options are approved per
-- question, rules row by row); release 87: the tables are registered in COMMON by 18h
--------------------------------------------------------------------------------
create or replace view xxcmp_config_changes_v as
select 'XXCMP_QUESTIONS:' || q.question_id                                   detail_pk,
       'Risk scoring answers'                                                 change_type,
       q.questionnaire_code || ' / ' || substr(q.question_text, 1, 200)       change_title,
       listagg(nvl(ao.answer_label, ao.lookup_code) || ': ' || ao.risk_points || ' points'
                 || case when ao.critical_flag = 'Y' then ', critical' end
                 || case when ao.waiver_qualifying_flag = 'Y' then ', waiver' end, '; ')
         within group (order by ao.display_sequence)                          change_summary,
       max(ao.last_updated_by)                                                submitted_by,
       max(ao.last_update_date)                                               submitted_date
  from xxcmp_answer_options ao
  join xxcmp_questions q on q.question_id = ao.question_id
 where ao.approval_status = 'PENDING_APPROVAL'
 group by q.question_id, q.questionnaire_code, q.question_text
union all
select 'XXCMP_ATTACHMENT_RULES:' || r.attachment_rule_id,
       'Mandatory document rule',
       r.entity_name || ' / ' || r.category_code,
       nvl(r.jurisdiction, 'any jurisdiction') || ' / ' || nvl(r.entity_type, 'any entity type')
         || ' / ' || case r.mandatory_flag when 'Y' then 'mandatory' else 'optional' end,
       r.last_updated_by,
       r.last_update_date
  from xxcmp_attachment_rules r
 where r.approval_status = 'PENDING_APPROVAL'
union all
-- release 74 (R16): risk model changes, one approval per table
select 'XXCMP_RISK_FACTOR_SET:KYC', 'Risk model factors', 'Risk factors',
       listagg(f.factor_name || ': ' || f.points || case when f.enabled_flag = 'N' then ' (off)' end
               || nvl2(f.force_tier, ', forces ' || f.force_tier, null), '; ') within group (order by f.display_sequence),
       max(f.last_updated_by), max(f.last_update_date)
  from xxcmp_risk_factors f
 where f.approval_status = 'PENDING_APPROVAL'
having count(*) > 0
union all
select 'XXCMP_RISK_COUNTRY_SET:KYC', 'Risk model country lists', 'Country lists',
       listagg(c.list_code || ' ' || c.country_code || case when c.enabled_flag = 'N' then ' (removed)' end, '; ')
         within group (order by c.list_code, c.country_code),
       max(c.last_updated_by), max(c.last_update_date)
  from xxcmp_risk_countries c
 where c.approval_status = 'PENDING_APPROVAL'
having count(*) > 0
union all
select 'XXCMP_RISK_TIER_SET:KYC', 'Risk model tiers', 'Risk tiers',
       listagg(t.risk_tier || ' from ' || t.min_score || ', review ' || t.review_months || ' months', '; ')
         within group (order by t.min_score),
       max(t.last_updated_by), max(t.last_update_date)
  from xxcmp_risk_tiers t
 where t.approval_status = 'PENDING_APPROVAL'
having count(*) > 0;
comment on table xxcmp_config_changes_v is 'KYC configuration changes waiting for approval (registered changes view in XXFND_CONFIG_TABLES).';
