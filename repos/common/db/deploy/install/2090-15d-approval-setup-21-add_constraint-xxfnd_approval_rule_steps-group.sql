--------------------------------------------------------------------------------
-- 15d step 21 (release 113): approval groups - the WHO triggers of the two new tables, and approver type GROUP on the
-- rule levels (the group code in ROLE_CODE): CK3 / CK4 are replaced by CK6 / CK7 with GROUP.
-- Idempotent: each constraint is dropped only while it exists and added only when missing; the triggers are replaced.
--------------------------------------------------------------------------------
begin
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPROVAL_GROUPS');
    xxfnd_schema_pkg.create_who_trigger('XXFND_APPROVAL_GROUP_MEMBERS');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK3');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK4');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK6',
        q'~check (approver_type in ('ROLE','USER','GROUP','REQUESTER','POSITION','MANAGER','SUP_HIER','POS_HIER','AOR','QUERY'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK7',
        q'~check ((approver_type in ('ROLE','GROUP') and role_code is not null) or (approver_type = 'USER' and user_name is not null)
                  or approver_type in ('REQUESTER','POSITION','MANAGER','SUP_HIER','POS_HIER','AOR','QUERY'))~');
end;
/
