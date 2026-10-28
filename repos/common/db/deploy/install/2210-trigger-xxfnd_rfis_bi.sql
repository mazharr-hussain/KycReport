
create or replace trigger xxfnd_rfis_bi
    before insert on xxfnd_rfis
    for each row
begin
    if :new.rfi_id is null then
        :new.rfi_id := xxfnd_rfi_s.nextval;
    end if;
    if :new.rfi_number is null then
        :new.rfi_number := 'RFI-' || lpad(xxfnd_rfi_number_s.nextval, 6, '0');
    end if;
end;
/
