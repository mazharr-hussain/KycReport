
create or replace view xxfnd_setup_columns_v as
select t.application_code, c.owner, c.table_name, c.column_name, c.column_id, c.data_type
  from all_tab_columns c
  join xxfnd_setup_tables_v t on t.owner = c.owner and t.table_name = c.table_name;
