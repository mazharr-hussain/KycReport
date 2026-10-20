
-- release 94 (UI issue 8): a placeholder approver type (HCM-based: position, manager, hierarchies, AOR, query) is listed
-- on the rule screen but cannot be saved until its resolver exists
create or replace trigger xxfnd_approval_rule_steps_type
    before insert or update of approver_type on xxfnd_approval_rule_steps
    for each row
begin
    if xxfnd_approval_rule_pkg.approver_type_available(:new.approver_type) = 'N' then
        raise_application_error(-20536, 'The approver type ' || xxfnd_approval_rule_pkg.approver_label(:new.approver_type, null, null)
            || ' is not available yet: it needs the HCM data (positions, managers, areas of responsibility). Choose a user, a role or the requester.');
    end if;
end;
/
