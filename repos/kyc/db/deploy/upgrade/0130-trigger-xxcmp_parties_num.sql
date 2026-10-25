
--==============================================================================
-- Numbering
--==============================================================================
create or replace trigger xxcmp_parties_num
    before insert on xxcmp_parties
    for each row
    when (new.party_number is null)
begin
    :new.party_number := 'P-' || lpad(xxcmp_party_number_s.nextval, 6, '0');
end;
/
