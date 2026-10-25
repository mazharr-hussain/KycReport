
create or replace trigger xxcmp_cases_lock
before update on xxcmp_cases
for each row
when (old.closed_date is not null)
begin
    -- release 41: the one-time fill of the new due diligence type
    if :old.due_diligence_type is null and not (updating('CASE_STATUS') or updating('DECISION') or updating('RISK_TIER')
                                                or updating('CLOSED_DATE') or updating('CONDITIONS') or updating('NEXT_REVIEW_DATE')
                                                or updating('ASSIGNED_TO') or updating('SAR_REQUIRED_FLAG') or updating('REQUEST_ID')) then
        return;
    end if;
    -- a user rename (XXFND_USER_PKG.RENAME_USER) only moves the user name columns to the new name
    if xxfnd_user_pkg.renaming then
        return;
    end if;
    -- a party merge (XXCMP_PARTY_PKG.MERGE_PARTIES) only re-points the case to the party that is kept
    if updating('PARTY_ID') and not (updating('CASE_STATUS') or updating('DECISION') or updating('RISK_TIER')
                                     or updating('CLOSED_DATE') or updating('CONDITIONS') or updating('NEXT_REVIEW_DATE')
                                     or updating('ASSIGNED_TO') or updating('SAR_REQUIRED_FLAG') or updating('REQUEST_ID')) then
        return;
    end if;
    raise_application_error(-20614, 'Case ' || :old.case_number || ' is closed and cannot be changed.');
end;
/
