create or replace editionable trigger xxcus.xxcmp_parties_num before
    insert on xxcus.xxcmp_parties
    for each row
    when ( new.party_number is null )
begin
    :new.party_number := 'P-'
                         || lpad(xxcmp_party_number_s.nextval, 6, '0');
end;
/

alter trigger xxcus.xxcmp_parties_num enable;


-- sqlcl_snapshot {"hash":"80fcba30f065d4adad4b326b254056de979ade9d","type":"TRIGGER","name":"XXCMP_PARTIES_NUM","schemaName":"XXCUS","sxml":""}