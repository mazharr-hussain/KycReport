--------------------------------------------------------------------------------
-- 15d step 23 (release 123, I-026): an approval group named by a rule level is kept in its own column GROUP_CODE
-- (it was kept in ROLE_CODE since release 113), on the rule levels and on the transaction steps copied from them.
-- Idempotent: each column / constraint is added only when missing (CK7 dropped only while it exists); the move updates
-- only GROUP rows still holding the code in ROLE_CODE, so a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_APPROVAL_RULE_STEPS', 'GROUP_CODE', 'varchar2(30)');
    xxfnd_ddl_pkg.add_column('XXFND_APPROVAL_TXN_STEPS', 'GROUP_CODE', 'varchar2(30)');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK7');
end;
/
-- the data move (static SQL would not compile before the columns exist on a first install: dynamic)
begin
    execute immediate q'~update xxfnd_approval_rule_steps set group_code = role_code, role_code = null
                          where approver_type = 'GROUP' and group_code is null and role_code is not null~';
    execute immediate q'~update xxfnd_approval_txn_steps set group_code = role_code, role_code = null
                          where approver_type = 'GROUP' and group_code is null and role_code is not null~';
    commit;
end;
/
begin
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK8',
        q'~check ((approver_type = 'ROLE' and role_code is not null) or (approver_type = 'GROUP' and group_code is not null)
                  or (approver_type = 'USER' and user_name is not null)
                  or approver_type in ('REQUESTER','POSITION','MANAGER','SUP_HIER','POS_HIER','AOR','QUERY'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_FK2',
        q'~foreign key (group_code) references xxfnd_approval_groups (group_code)~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_approval_rule_steps.group_code is 'Release 123: the approval group of a GROUP level (XXFND_APPROVAL_GROUPS); ROLE_CODE is for a ROLE level only.'~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_approval_txn_steps.group_code is 'Release 123: the approval group of a GROUP step, copied from the rule level.'~');
end;
/
