
-- release 79: Effective access - per user, every enabled rule that applies, assigned directly or through an active
-- role (the User screen's Data access tab; access adds up: the widest rule of a table wins)
create or replace view xxfnd_effective_access_v as
select u.user_id,
       u.user_name,
       d.rule_id,
       d.table_name,
       d.rule_type,
       d.column_name,
       d.value_list,
       a.assignment_id,
       case when a.user_id is not null then 'Direct' else 'Role ' || r.role_name end as granted_through,
       a.role_code
  from xxfnd_users u
  join xxfnd_data_rule_assignments a
    on a.user_id = u.user_id
    or a.role_code in (select ur.role_code from xxfnd_user_roles_v ur where ur.user_id = u.user_id and ur.active_flag = 'Y')
  join xxfnd_data_security_rules d on d.rule_id = a.rule_id and d.enabled_flag = 'Y'
  left join xxfnd_roles r on r.role_code = a.role_code;

comment on table xxfnd_effective_access_v is 'The data access rules that apply to each user, directly or through an active role.';
