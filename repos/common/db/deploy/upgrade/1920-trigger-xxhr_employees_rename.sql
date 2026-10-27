
-- An employee's user name changed (Fusion user name from the HCM sync, or a LOCAL edit): every stored reference
-- moves to the new name (xxfnd_user_pkg.rename_user), so the person keeps their requests, cases and tasks.
create or replace trigger xxhr_employees_rename
    after update of user_name on xxhr_employees
    for each row
    when (upper(new.user_name) <> upper(old.user_name))
begin
    xxfnd_user_pkg.rename_user(:old.user_name, :new.user_name);
end;
/
