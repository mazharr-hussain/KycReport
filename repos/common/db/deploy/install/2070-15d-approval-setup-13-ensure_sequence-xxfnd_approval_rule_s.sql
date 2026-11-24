begin

    xxfnd_ddl_pkg.ensure_sequence('XXFND_APPROVAL_RULE_S', 'create sequence xxfnd_approval_rule_s');

    -- release 94 (UI issue 8): approver types as in AME / BPM - USER (in use now), ROLE, REQUESTER, and the HCM-based
    -- types kept as placeholders until the HCM data is loaded: POSITION, MANAGER, SUP_HIER (supervisor hierarchy),
    -- POS_HIER (position hierarchy), AOR (area of responsibility), QUERY (a query returning the approvers);
    -- APPROVER_VALUE holds their setting (position, levels, query); DUE_DAYS = the step's deadline (days)
    xxfnd_ddl_pkg.add_column('XXFND_APPROVAL_RULE_STEPS', 'APPROVER_VALUE', 'varchar2(4000)');
    xxfnd_ddl_pkg.add_column('XXFND_APPROVAL_RULE_STEPS', 'DUE_DAYS', 'number');
    xxfnd_ddl_pkg.add_column('XXFND_APPROVAL_TXN_STEPS', 'DUE_DAYS', 'number');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK1');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK2');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK3',
        q'~check (approver_type in ('ROLE','USER','REQUESTER','POSITION','MANAGER','SUP_HIER','POS_HIER','AOR','QUERY'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK4',
        q'~check ((approver_type = 'ROLE' and role_code is not null) or (approver_type = 'USER' and user_name is not null)
                  or approver_type in ('REQUESTER','POSITION','MANAGER','SUP_HIER','POS_HIER','AOR','QUERY'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPROVAL_RULE_STEPS', 'XXFND_APPROVAL_RULE_STEPS_CK5', 'check (due_days > 0)');

end;
/
