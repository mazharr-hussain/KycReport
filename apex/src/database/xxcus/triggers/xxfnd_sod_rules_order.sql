create or replace editionable trigger xxcus.xxfnd_sod_rules_order before
    insert or update of role_code_1, role_code_2 on xxcus.xxfnd_sod_rules
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

alter trigger xxcus.xxfnd_sod_rules_order enable;


-- sqlcl_snapshot {"hash":"81b60c37e9f01418ca377937739399c397071dff","type":"TRIGGER","name":"XXFND_SOD_RULES_ORDER","schemaName":"XXCUS","sxml":""}