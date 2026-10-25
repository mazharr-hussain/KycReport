
create or replace trigger xxcmp_attachment_rules_mc
    before insert or update on xxcmp_attachment_rules
    for each row
begin
    xxfnd_approval_pkg.apply_rules(inserting, :old.approval_status, :new.approval_status,
                                   :old.last_updated_by, :new.approved_by, :new.approved_date);
end;
/
