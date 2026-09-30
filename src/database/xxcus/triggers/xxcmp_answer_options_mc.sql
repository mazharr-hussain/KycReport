create or replace editionable trigger xxcus.xxcmp_answer_options_mc before
    insert or update on xxcus.xxcmp_answer_options
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

alter trigger xxcus.xxcmp_answer_options_mc enable;


-- sqlcl_snapshot {"hash":"2f4c8dc3b00b2b4e49ffe7cb9a1425e6f8efa7de","type":"TRIGGER","name":"XXCMP_ANSWER_OPTIONS_MC","schemaName":"XXCUS","sxml":""}