create or replace editionable trigger xxcus.xxcmp_attachment_rules_mc before
    insert or update on xxcus.xxcmp_attachment_rules
    for each row
begin
    xxfnd_approval_pkg.apply_rules(inserting,
                                   :old.approval_status,
                                   :new.approval_status,
                                   :old.last_updated_by,
                                   :new.approved_by,
                                   :new.approved_date);
end;
/

alter trigger xxcus.xxcmp_attachment_rules_mc enable;


-- sqlcl_snapshot {"hash":"1c58d298afcb011a59fcc526b189e97d0378e8c1","type":"TRIGGER","name":"XXCMP_ATTACHMENT_RULES_MC","schemaName":"XXCUS","sxml":""}