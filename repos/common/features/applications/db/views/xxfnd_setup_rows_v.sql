
-- every setup row that belongs to an application (release 73: the application's overview, COMMON page 161)
create or replace view xxfnd_setup_rows_v as
select 'LOOKUPS' setup_type_code, application_code, lookup_type row_key, lookup_type || ' - ' || meaning row_name, 'P102_LOOKUP_TYPE' form_item
  from xxfnd_lookup_types
union all
select 'VALUE_SETS', application_code, value_set_code, value_set_code || ' - ' || value_set_name, 'P151_VALUE_SET_CODE'
  from xxfnd_value_sets
union all
select 'FLEXFIELDS', application_code, descriptive_flexfield_code, descriptive_flexfield_code || ' - ' || table_name, 'P153_DESCRIPTIVE_FLEXFIELD_CODE'
  from xxfnd_df_flexfields
union all
select 'DOCUMENT_CATEGORIES', application_code, category_code, category_code || ' - ' || category_name, 'P133_CATEGORY_CODE'
  from xxfnd_document_categories
union all
select 'DOCUMENT_STORAGE', application_code, nvl(application_code, 'COMMON'),
       nvl(category_code, 'Application default') || ' - ' || nvl(server_code, nvl(storage_type, 'as the application')), 'P137_APPLICATION_CODE'
  from xxfnd_storage_config
 where enabled_flag = 'Y'
union all
select 'DOCUMENT_ENTITIES', application_code, entity_name, entity_name || ' - ' || table_name, 'P131_ENTITY_NAME'
  from xxfnd_document_entities
union all
select 'ATTACHMENT_PAGES', application_code, function_code, function_code || ' - ' || function_name, 'P135_FUNCTION_CODE'
  from xxfnd_attachment_functions
union all
select 'NOTIFICATION_TEMPLATES', application_code, template_code, template_code || ' - ' || subject, 'P110_TEMPLATE_CODE'
  from xxfnd_notification_templates
union all
select 'RETENTION_POLICIES', application_code, to_char(retention_policy_id), table_name || nvl2(jurisdiction, ' (' || jurisdiction || ')', null), 'P113_RETENTION_POLICY_ID'
  from xxfnd_retention_policies
union all
select 'SERVERS', cast(null as varchar2(30)), server_code, server_code || ' - ' || server_name, 'P121_SERVER_CODE'
  from xxfnd_servers
union all
select 'INTEGRATION_PURPOSES', application_code, purpose_code, purpose_code || ' - ' || purpose_name, 'P123_PURPOSE_CODE'
  from xxfnd_integration_purposes
union all
select 'ROLES', application_code, role_code, role_code || ' - ' || role_name, 'P106_ROLE_CODE'
  from xxfnd_roles
union all
select 'SEGREGATION_OF_DUTIES', r.application_code, to_char(s.sod_rule_id), s.role_code_1 || ' / ' || s.role_code_2, 'P108_SOD_RULE_ID'
  from xxfnd_sod_rules s
  join xxfnd_roles r on r.role_code = s.role_code_1
union all
-- release 96: the data objects of the security model (page 181 opens one)
select 'DATA_SECURITY', o.application_code, o.data_object_code, o.object_name || ' - ' || o.table_name, 'P181_DATA_OBJECT_CODE'
  from xxfnd_data_objects o;

comment on table xxfnd_setup_rows_v is 'Every setup row with its application (empty: all applications - instance) and the COMMON form item that opens it.';
