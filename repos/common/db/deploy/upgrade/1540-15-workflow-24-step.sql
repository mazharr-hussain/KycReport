
--------------------------------------------------------------------------------
-- Configuration changes (maker-checker): the row rules and the approval of a change, one package (release 84: the
-- approval is the COMMON workflow process CONFIG_CHANGE; this package keeps the rules)
-- (release 74: XXFND_CONFIG_APPROVAL_PKG merged into XXFND_APPROVAL_PKG; the body moved here from 06 because the
-- approval task needs XXFND_WORKFLOW_PKG above).
--------------------------------------------------------------------------------
begin
    execute immediate 'drop package xxfnd_config_approval_pkg';
exception
    when others then
        if sqlcode <> -4043 then
            raise;
        end if;
end;
/
