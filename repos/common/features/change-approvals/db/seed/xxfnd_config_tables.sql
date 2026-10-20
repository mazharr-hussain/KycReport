
-- the shared configuration tables
merge into xxfnd_config_tables t
using (select column_value table_name
         from table(apex_t_varchar2(
              'XXFND_LOOKUP_TYPES','XXFND_LOOKUP_VALUES','XXHR_EMPLOYEES','XXFND_ROLES','XXFND_USER_ROLES',
              'XXFND_SOD_RULES','XXFND_NOTIFICATION_TEMPLATES','XXFND_RETENTION_POLICIES',
              'XXFND_INTEGRATION_PURPOSES',
              'XXFND_DOCUMENT_ENTITIES','XXFND_DOCUMENT_CATEGORIES','XXFND_ATTACHMENT_FUNCTIONS',
              'XXFND_ATTACHMENT_BLOCKS','XXFND_ATTACHMENT_BLK_ENTITIES','XXFND_DOC_CATEGORY_USAGES',
              'XXFND_STORAGE_CONFIG','XXFND_WF_DELEGATIONS',
              'XXFND_VALUE_SETS','XXFND_DF_FLEXFIELDS','XXFND_DF_CONTEXTS','XXFND_DF_SEGMENTS'))) s
   on (t.table_name = s.table_name)
 when not matched then insert (table_name, application_id, audit_flag, created_by, creation_date, last_updated_by, last_update_date)
                       values (s.table_name, (select application_id from xxfnd_applications where application_code = 'COMMON'), 'Y',
                               'INSTALL', systimestamp, 'INSTALL', systimestamp);
update xxfnd_config_tables
   set approval_flag = 'Y', pk_column = 'PURPOSE_CODE', changes_view = 'XXFND_INTEGRATION_CHANGES_V'
 where table_name = 'XXFND_INTEGRATION_PURPOSES' and approval_flag = 'N';
commit;
