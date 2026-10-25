
-- each rule's own role is its first assignment (once; a re-run adds nothing)
merge into xxfnd_data_rule_assignments t
using (select rule_id, role_code from xxfnd_data_security_rules where role_code is not null) s
   on (t.rule_id = s.rule_id and t.role_code = s.role_code)
 when not matched then insert (rule_id, role_code, created_by, creation_date, last_updated_by, last_update_date)
                       values (s.rule_id, s.role_code, 'INSTALL', systimestamp, 'INSTALL', systimestamp);
commit;
