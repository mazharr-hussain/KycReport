create or replace editionable trigger xxcus.xxfnd_employees_ins before
    insert on xxcus.xxfnd_employees
    for each row
begin
    :new.user_name := upper(:new.user_name);
    :new.email_address := lower(:new.email_address);
end;
/

alter trigger xxcus.xxfnd_employees_ins enable;


-- sqlcl_snapshot {"hash":"d5546e8b03c47834a3660f8d60fdfcf8f759c001","type":"TRIGGER","name":"XXFND_EMPLOYEES_INS","schemaName":"XXCUS","sxml":""}