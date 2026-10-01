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

create or replace view xxfnd_attached_documents_v as
select ad.attached_document_id,
       ad.entity_name,
       ad.pk1_value, ad.pk2_value, ad.pk3_value, ad.pk4_value, ad.pk5_value,
       ad.category_code,
       c.category_name,
       ad.seq_num,
       ad.primary_category_flag,
       d.document_id,
       d.base_document_id,
       d.version_number,
       d.datatype_code,
       nvl(dt.title, d.file_name)         title,
       dt.description,
       d.file_name,
       d.mime_type,
       d.file_size_bytes,
       d.url,
       d.external_url,
       d.storage_type,
       d.document_date,
       d.expiry_date,
       case when d.expiry_date < trunc(sysdate) then 'Y' else 'N' end expired_flag,
       d.upload_status,
       d.upload_error,
       d.automated_check_status,
       ad.created_by,
       ad.creation_date
  from xxfnd_attached_documents ad
  join xxfnd_documents d on d.document_id = ad.document_id
  join xxfnd_document_categories_vl c on c.category_code = ad.category_code
  left join xxfnd_documents_tl dt
    on dt.document_id = d.document_id
   and dt.language_code = xxfnd_util_pkg.current_lang
 where ad.expiration_date is null;
comment on table xxfnd_attached_documents_v is 'Attachments not removed, with category and title resolved. XXFND_ATTACH_PKG.ADD_VERSION repoints the attachment to the newest version, so DOCUMENT_ID is always the current one.';

create or replace view xxfnd_document_versions_v as
select d.document_id,
       nvl(d.base_document_id, d.document_id) base_document_id,
       d.version_number,
       d.file_name,
       d.mime_type,
       d.file_size_bytes,
       d.storage_type,
       d.external_version_id,
       d.document_date,
       d.expiry_date,
       d.created_by,
       d.creation_date
  from xxfnd_documents d
 where d.datatype_code = 'FILE';
comment on table xxfnd_document_versions_v is 'Every stored version of a file; filter by BASE_DOCUMENT_ID for one document''s history.';

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

create or replace view xxfnd_df_segments_vl as
select s.descriptive_flexfield_code,
       s.context_code,
       c.global_flag,
       s.segment_code,
       s.column_name,
       s.sequence_number,
       nvl(t.prompt, s.prompt)            prompt,
       nvl(t.help_text, s.help_text)      help_text,
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
  from xxfnd_df_segments s
  join xxfnd_df_contexts c
    on c.descriptive_flexfield_code = s.descriptive_flexfield_code
   and c.context_code = s.context_code
  join xxfnd_value_sets vs on vs.value_set_code = s.value_set_code
  left join xxfnd_df_segments_tl t
    on t.descriptive_flexfield_code = s.descriptive_flexfield_code
   and t.context_code = s.context_code
   and t.segment_code = s.segment_code
   and t.language_code = xxfnd_util_pkg.current_lang;

create or replace view xxfnd_pending_approvals_v as
select 'XXCMP_ANSWER_OPTIONS'                       table_name,
       'Risk scoring answer'                        change_type,
       to_char(ao.answer_option_id)                 pk_value,
       q.questionnaire_code || ' / ' || substr(q.question_text, 1, 120) || ' / '
         || nvl(ao.answer_label, ao.lookup_code)
         || ' / points ' || ao.risk_points
         || case when ao.critical_flag = 'Y' then ' / critical' end
         || case when ao.waiver_qualifying_flag = 'Y' then ' / waiver' end change_summary,
       ao.last_updated_by                           submitted_by,
       ao.last_update_date                          submitted_date,
       ao.approval_status
  from xxcmp_answer_options ao
  join xxcmp_questions q on q.question_id = ao.question_id
 where ao.approval_status = 'PENDING_APPROVAL'
union all
select 'XXCMP_ATTACHMENT_RULES',
       'Mandatory document rule',
       to_char(r.attachment_rule_id),
       r.entity_name || ' / ' || r.category_code
         || ' / ' || nvl(r.jurisdiction, 'any jurisdiction') || ' / ' || nvl(r.entity_type, 'any entity type')
         || ' / ' || case r.mandatory_flag when 'Y' then 'mandatory' else 'optional' end,
       r.last_updated_by,
       r.last_update_date,
       r.approval_status
  from xxcmp_attachment_rules r
 where r.approval_status = 'PENDING_APPROVAL'
union all
select 'XXFND_INTEGRATION_PURPOSES',
       'Integration purpose',
       p.purpose_code,
       p.purpose_name || ' / ' || p.capture_method || ' / ' || nvl(p.endpoint_code, 'no endpoint'),
       p.last_updated_by,
       p.last_update_date,
       p.approval_status
  from xxfnd_integration_purposes p
 where p.approval_status = 'PENDING_APPROVAL';
comment on table xxfnd_pending_approvals_v is 'Config Change Approvals queue: every maker-checker change waiting for a second person.';

-- One approval unit per CONFIG_CHANGE task. DETAIL_PK = '<TABLE>:<KEY>' is the task's detail key;
-- all pending answer options of one question are approved together ('XXCMP_QUESTIONS:<question id>').
create or replace view xxfnd_config_changes_v as
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
select 'XXFND_INTEGRATION_PURPOSES:' || p.purpose_code,
       'Integration purpose',
       p.purpose_name,
       p.capture_method || ' / ' || nvl(p.endpoint_code, 'no endpoint'),
       p.last_updated_by,
       p.last_update_date
  from xxfnd_integration_purposes p
 where p.approval_status = 'PENDING_APPROVAL';
comment on table xxfnd_config_changes_v is 'Maker-checker changes waiting for approval, one row per CONFIG_CHANGE approval task (DETAIL_PK).';
