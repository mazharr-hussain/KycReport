
-- A user's roles including the roles inside them (any depth): ASSIGNED_ROLE_CODE is the role of the assignment
-- (USER_ROLE_ID, which holds the data access values), ROLE_CODE every role it brings.
create or replace view xxfnd_user_role_tree_v as
with tree (user_role_id, user_id, user_name, assigned_role_code, role_code, active_flag, lvl) as (
    select ur.user_role_id, ur.user_id, ur.user_name, ur.role_code, ur.role_code, ur.active_flag, 0
      from xxfnd_user_roles_v ur
    union all
    select t.user_role_id, t.user_id, t.user_name, t.assigned_role_code, m.member_role_code,
           case when t.active_flag = 'Y' and r.enabled_flag = 'Y' then 'Y' else 'N' end, t.lvl + 1
      from tree t
      join xxfnd_role_members m on m.role_code = t.role_code
      join xxfnd_roles r        on r.role_code = m.member_role_code
     where t.lvl < 10
)
cycle role_code set is_cycle to 'Y' default 'N'
select user_role_id, user_id, user_name, assigned_role_code, role_code, active_flag, lvl
  from tree
 where is_cycle = 'N';
