
-- the tables and columns the setup forms list (release 73): the registered applications' schemas and this one
create or replace view xxfnd_setup_tables_v as
select a.application_code, t.owner, t.table_name
  from all_tables t
  join xxfnd_applications a on upper(a.schema_name) = t.owner
 where t.owner <> user
   and t.table_name not like 'DR$%' and t.table_name not like 'MLOG$%' and t.table_name not like 'SYS\_%' escape '\'
union all
select null, user, t.table_name
  from user_tables t
 where t.table_name not like 'DR$%' and t.table_name not like 'MLOG$%' and t.table_name not like 'SYS\_%' escape '\';

comment on table xxfnd_setup_tables_v is 'Tables the COMMON setup forms list: each registered application''s schema (APPLICATION_CODE) and this schema (empty: every application).';
