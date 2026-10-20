
-- The data access a user has per data object: every level a role brings (assigned or inside an assigned role), and
-- for level VALUES the values of that assignment - the object's own values (override) when there are any, otherwise
-- the dimension's default values. One row per user, object, level, granting role and value.
create or replace view xxfnd_user_data_access_v as
select t.user_id, t.user_name, t.user_role_id, t.assigned_role_code, t.role_code as granted_by_role_code,
       o.data_object_code, o.object_name, o.application_code, o.table_name, o.dimension_code, o.dimension_column,
       o.owner_column, a.access_level,
       case when a.access_level = 'VALUES' then v.value_code end as value_code,
       case when a.access_level <> 'VALUES' then null
            when exists (select 1 from xxfnd_assignment_values x
                          where x.user_role_id = t.user_role_id and x.dimension_code = o.dimension_code
                            and x.data_object_code = o.data_object_code) then 'OVERRIDE'
            else 'DEFAULT' end as value_scope,
       -- release 102: the value as DIMENSION_COLUMN holds it - the code, or for ID the organization's ID
       case when a.access_level <> 'VALUES' then null
            when o.dimension_value_type = 'ID' then
                 (select to_char(g.organization_id)
                    from xxfnd_data_dimensions d
                    join xxhr_organizations g on g.organization_type = d.organization_type
                   where d.dimension_code = o.dimension_code and g.organization_code = v.value_code)
            else v.value_code end as dimension_value,
       o.dimension_value_type
  from xxfnd_user_role_tree_v t
  join xxfnd_role_data_access a on a.role_code = t.role_code
  join xxfnd_data_objects o     on o.data_object_code = a.data_object_code and o.enabled_flag = 'Y'
  left join xxfnd_assignment_values v
    on a.access_level = 'VALUES'
   and v.user_role_id = t.user_role_id
   and v.dimension_code = o.dimension_code
   and (v.data_object_code = o.data_object_code
        or (v.data_object_code is null
            and not exists (select 1 from xxfnd_assignment_values x
                             where x.user_role_id = t.user_role_id and x.dimension_code = o.dimension_code
                               and x.data_object_code = o.data_object_code)))
 where t.active_flag = 'Y';

comment on table xxfnd_user_data_access_v is 'Release 96: the data access of each user (active roles, including roles inside roles): object, level and, for VALUES, the values that apply (OVERRIDE for the object, else the DEFAULT of the dimension).';
