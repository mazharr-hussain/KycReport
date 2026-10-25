
-- a stored file may now be in the database
declare
    l_cond varchar2(4000);
begin
    select search_condition_vc into l_cond from user_constraints
     where table_name = 'XXFND_DOCUMENTS' and constraint_name = 'XXFND_DOCUMENTS_CK4';
    if instr(l_cond, 'DATABASE') = 0 then
        execute immediate 'alter table xxfnd_documents drop constraint xxfnd_documents_ck4';
        execute immediate q'[alter table xxfnd_documents add constraint xxfnd_documents_ck4 check (
            (datatype_code = 'FILE'     and storage_type in ('UCM','SHAREPOINT','DATABASE') and file_name is not null) or
            (datatype_code = 'WEB_PAGE' and url is not null and storage_type is null) or
            (datatype_code in ('SHORT_TEXT','LONG_TEXT') and storage_type is null))]';
    end if;
end;
/
