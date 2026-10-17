
-- every employee with a grant becomes an SSO user, and the grants move to the user
insert into xxfnd_users (user_name, user_type, employee_id, full_name, email_address, enabled_flag,
                         start_date_active, end_date_active,
                         created_by, creation_date, last_updated_by, last_update_date)
select upper(e.user_name), 'SSO', e.employee_id, e.full_name, e.email_address, e.enabled_flag,
       e.start_date_active, e.end_date_active, 'INSTALL', systimestamp, 'INSTALL', systimestamp
  from xxfnd_employees e
 where exists (select 1 from xxfnd_user_roles ur where ur.employee_id = e.employee_id)
   and not exists (select 1 from xxfnd_users u where u.employee_id = e.employee_id)
   and not exists (select 1 from xxfnd_users u where u.user_name = upper(e.user_name));
