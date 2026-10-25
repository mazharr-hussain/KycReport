
-- a rule created or changed with a role (seeds, scripts) is assigned to that role as well
create or replace trigger xxfnd_data_rules_assign
    after insert or update of role_code on xxfnd_data_security_rules
    for each row
    when (new.role_code is not null)
begin
    merge into xxfnd_data_rule_assignments t
    using (select :new.rule_id rule_id, :new.role_code role_code from dual) s
       on (t.rule_id = s.rule_id and t.role_code = s.role_code)
     when not matched then insert (rule_id, role_code) values (s.rule_id, s.role_code);
end;
/
