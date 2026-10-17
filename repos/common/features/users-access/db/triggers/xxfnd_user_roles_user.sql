
-- a grant made for an employee (screens before release 46, the installer) goes to the employee's user, created
-- on the fly as an SSO user
create or replace trigger xxfnd_user_roles_user
before insert or update of employee_id, user_id on xxfnd_user_roles
for each row
when (new.user_id is null and new.employee_id is not null)
declare
    l_user_id xxfnd_users.user_id%type;
    l_emp     xxfnd_employees%rowtype;
begin
    select max(user_id) into l_user_id from xxfnd_users where employee_id = :new.employee_id;
    if l_user_id is null then
        select * into l_emp from xxfnd_employees where employee_id = :new.employee_id;
        insert into xxfnd_users (user_name, user_type, employee_id, full_name, email_address)
        values (upper(l_emp.user_name), 'SSO', l_emp.employee_id, l_emp.full_name, l_emp.email_address)
        returning user_id into l_user_id;
    end if;
    :new.user_id := l_user_id;
end;
/
