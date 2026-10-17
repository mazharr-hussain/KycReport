
--------------------------------------------------------------------------------

-- release 46: grants belong to the user (XXFND_USERS); an SSO user is linked to an employee, a LOCAL user is not
create or replace view xxfnd_user_roles_v as
select ur.user_role_id,
       u.user_id,
       u.employee_id,
       u.user_name,
       coalesce(e.full_name, u.full_name, u.user_name) full_name,
       nvl(e.source_type, 'LOCAL') source_type,
       u.user_type,
       ur.role_code,
       r.role_name,
       r.application_code,
       r.application_id,
       ur.start_date_active,
       ur.end_date_active,
       ur.enabled_flag,
       case when ur.enabled_flag = 'Y' and r.enabled_flag = 'Y' and u.enabled_flag = 'Y'
             and trunc(sysdate) between ur.start_date_active and nvl(ur.end_date_active, trunc(sysdate))
             and trunc(sysdate) between u.start_date_active  and nvl(u.end_date_active,  trunc(sysdate))
             and (e.employee_id is null
                  or (e.enabled_flag = 'Y' and trunc(sysdate) between e.start_date_active and nvl(e.end_date_active, trunc(sysdate))))
            then 'Y' else 'N' end active_flag
  from xxfnd_user_roles ur
  join xxfnd_users u          on u.user_id     = ur.user_id
  left join xxfnd_employees e on e.employee_id = u.employee_id
  join xxfnd_roles r          on r.role_code   = ur.role_code;
