create or replace editionable trigger xxcus.xxcmp_cases_lock before
    update on xxcus.xxcmp_cases
    for each row
    when ( old.closed_date is not null )
begin
    raise_application_error(-20614,
                            'Case '
                            || :old.case_number
                            || ' is closed and cannot be changed.');
end;
/

alter trigger xxcus.xxcmp_cases_lock enable;


-- sqlcl_snapshot {"hash":"6fc9e88341eeeece08c1c8ba1309e1eb640c5293","type":"TRIGGER","name":"XXCMP_CASES_LOCK","schemaName":"XXCUS","sxml":""}