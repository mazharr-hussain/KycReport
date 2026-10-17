
create or replace trigger xxfnd_approval_rules_bi
    before insert on xxfnd_approval_rules
    for each row
    when (new.rule_id is null)
begin
    :new.rule_id := xxfnd_approval_rule_s.nextval;
end;
/
