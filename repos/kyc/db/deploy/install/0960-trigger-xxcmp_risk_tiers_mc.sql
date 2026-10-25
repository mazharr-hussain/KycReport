
create or replace trigger xxcmp_risk_tiers_mc
    before insert or update on xxcmp_risk_tiers
    for each row
begin
    xxfnd_approval_pkg.apply_rules(inserting, :old.approval_status, :new.approval_status,
                                   :old.last_updated_by, :new.approved_by, :new.approved_date);
    if :new.approval_status = 'APPROVED' and (inserting or nvl(:old.approval_status, '#') <> 'APPROVED') then
        :new.approved_min_score     := :new.min_score;
        :new.approved_review_months := :new.review_months;
    end if;
end;
/
