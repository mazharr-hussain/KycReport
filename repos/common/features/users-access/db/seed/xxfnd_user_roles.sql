
update xxfnd_user_roles ur
   set ur.user_id = (select u.user_id from xxfnd_users u where u.employee_id = ur.employee_id)
 where ur.user_id is null and ur.employee_id is not null;
commit;
