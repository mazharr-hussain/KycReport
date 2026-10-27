
-- Release 86: a new role gets the privileges every role holds, whichever way it is made (application journey, Roles
-- screen, registration routine, an application's install) - the install scripts give them to the existing roles.
create or replace trigger xxfnd_roles_every_role
    after insert on xxfnd_roles
    for each row
begin
    xxfnd_privilege_pkg.give_every_role_privileges(:new.role_code);
end;
/
