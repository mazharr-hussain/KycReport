
-- SoD pairs are stored in canonical order whatever order the user picks.
create or replace trigger xxfnd_sod_rules_order
    before insert or update of role_code_1, role_code_2 on xxfnd_sod_rules
    for each row
declare
    l_tmp varchar2(30);
begin
    if :new.role_code_1 > :new.role_code_2 then
        l_tmp := :new.role_code_1;
        :new.role_code_1 := :new.role_code_2;
        :new.role_code_2 := l_tmp;
    end if;
end;
/

-- (release 79: the trigger XXHR_EMPLOYEES_RENAME is created with XXFND_USER_PKG, script 16j)
