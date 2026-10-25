
-- release 83: XXHR_EMPLOYEES_SRC (Fusion-owned rows) is created in 05b, after XXFND_INTEGRATION_PKG.

create or replace trigger xxhr_employees_ins
    before insert on xxhr_employees
    for each row
begin
    :new.user_name := upper(:new.user_name);
    :new.email_address := lower(:new.email_address);
end;
/
