declare
    l_n pls_integer;
begin
    xxfnd_schema_pkg.create_who_trigger('XXFND_RFIS');
    -- who provides the information can come from the Approval Setup (e.g. CASE_RFI: the requester by default)
    xxfnd_ddl_pkg.add_column('XXFND_RFIS', 'APPROVAL_TYPE_CODE', 'varchar2(30)');
    -- release 82: the language of the e-mail to an outside recipient (no user record), default English
    xxfnd_ddl_pkg.add_column('XXFND_RFIS', 'LANGUAGE_CODE', q'~varchar2(10) default 'en'~');
    -- release 84: the RFI workflow (COMMON process RFI) of the request
    xxfnd_ddl_pkg.add_column('XXFND_RFIS', 'WORKFLOW_ID', 'number');
end;
/
