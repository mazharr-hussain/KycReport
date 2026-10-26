
-- maker-checker on the model tables; the values in use are copied when a change is approved
create or replace trigger xxcmp_risk_factors_mc
    before insert or update on xxcmp_risk_factors
    for each row
begin
    xxfnd_approval_pkg.apply_rules(inserting, :old.approval_status, :new.approval_status,
                                   :old.last_updated_by, :new.approved_by, :new.approved_date);
    if :new.approval_status = 'APPROVED' and (inserting or nvl(:old.approval_status, '#') <> 'APPROVED') then
        :new.approved_points       := :new.points;
        :new.approved_force_tier   := :new.force_tier;
        :new.approved_enabled_flag := :new.enabled_flag;
    end if;
end;
/
