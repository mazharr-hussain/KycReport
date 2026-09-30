create or replace editionable trigger xxcus.xxcmp_rfis_num before
    insert on xxcus.xxcmp_rfis
    for each row
    when ( new.rfi_number is null )
begin
    :new.rfi_number := 'RFI-'
                       || lpad(xxcmp_rfi_number_s.nextval, 6, '0');
end;
/

alter trigger xxcus.xxcmp_rfis_num enable;


-- sqlcl_snapshot {"hash":"642ebd0c3b1b7450832667d1ee6eb427acef2184","type":"TRIGGER","name":"XXCMP_RFIS_NUM","schemaName":"XXCUS","sxml":""}