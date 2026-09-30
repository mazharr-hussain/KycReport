create or replace editionable trigger xxcus.xxfnd_int_purposes_mc before
    insert or update on xxcus.xxfnd_integration_purposes
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

alter trigger xxcus.xxfnd_int_purposes_mc enable;


-- sqlcl_snapshot {"hash":"371fbd11c088b8ae2b9d3e022e16cdf8ca133f81","type":"TRIGGER","name":"XXFND_INT_PURPOSES_MC","schemaName":"XXCUS","sxml":""}