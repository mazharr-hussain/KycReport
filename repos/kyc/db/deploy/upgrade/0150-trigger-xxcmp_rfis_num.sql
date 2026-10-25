
create or replace trigger xxcmp_rfis_num
    before insert on xxcmp_rfis
    for each row
    when (new.rfi_number is null)
begin
    :new.rfi_number := 'RFI-' || lpad(xxcmp_rfi_number_s.nextval, 6, '0');
end;
/
