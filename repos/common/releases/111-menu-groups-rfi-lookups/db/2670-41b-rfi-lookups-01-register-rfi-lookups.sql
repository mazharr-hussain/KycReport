--------------------------------------------------------------------------------
-- 41b COMMON 111: the RFI lookups belong to COMMON (its RFI reads them), so COMMON on its own shows their names.
--   RFI_STATUS and RFI_RECIPIENT_TYPE hold the values XXFND_RFIS allows; RFI_CATEGORY a few general categories
--   (an application adds its own). A type an application registered before becomes a shared COMMON type; its values
--   stay. Re-runnable: only what is missing is added.
--------------------------------------------------------------------------------
declare
    procedure lookups(p_type in varchar2, p_meaning in varchar2, p_level in varchar2, p_values in varchar2) is
        l_parts apex_t_varchar2;
        l_seq   pls_integer := 0;
    begin
        -- a type registered by an application becomes COMMON's (shared: no application)
        update xxfnd_lookup_types set application_code = null
         where lookup_type = p_type and application_code is not null;
        xxfnd_lookup_pkg.register_lookup_type('COMMON', p_type, p_meaning, p_level);
        for v in (select column_value item from table(apex_string.split(p_values, '|'))) loop
            l_seq   := l_seq + 10;
            l_parts := apex_string.split(v.item, '=');
            xxfnd_lookup_pkg.register_lookup_value('COMMON', p_type, l_parts(1), l_parts(2), l_seq);
        end loop;
    end lookups;
begin
    xxfnd_util_pkg.set_install_mode(true);
    lookups('RFI_STATUS', 'RFI Status', 'S',
        'WAITING_FOR_INFORMATION=Waiting for information|ON_HOLD_PENDING=On hold - pending'
        || '|ON_HOLD_INVESTIGATION=On hold - investigation|RESOLVED=Resolved|REJECTED_RETURNED=Rejected / returned'
        || '|CANCELLED=Cancelled|RESPONDED=Answered - waiting for review');
    lookups('RFI_RECIPIENT_TYPE', 'RFI Recipient Types', 'S',
        'USER=User (answers in My Tasks)|EXTERNAL=External person (answers through the e-mailed link)');
    lookups('RFI_CATEGORY', 'RFI Categories', 'E',
        'CLARIFICATION=Clarification|MISSING_DOCUMENT=Missing document|OTHER=Other');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
