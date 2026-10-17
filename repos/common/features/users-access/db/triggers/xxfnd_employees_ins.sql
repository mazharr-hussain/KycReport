
-- release 83: XXFND_EMPLOYEES_SRC (Fusion-owned rows) is created in 05b, after XXFND_INTEGRATION_PKG.

create or replace trigger xxfnd_employees_ins
    before insert on xxfnd_employees
    for each row
begin
    :new.user_name := upper(:new.user_name);
    :new.email_address := lower(:new.email_address);
end;
/
