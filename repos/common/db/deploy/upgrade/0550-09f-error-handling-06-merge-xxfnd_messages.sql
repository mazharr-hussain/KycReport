
-- The common messages (administrators may change the texts; existing rows are kept).
merge into xxfnd_messages d
using (select 'XXFND_UNEXPECTED_ERROR' code, 'Something went wrong and the action was not completed. Please try again; if it happens again, contact support with reference {1}.' txt, null num, 'Shown for any unexpected error; {1} = the error log reference.' dsc from dual
       union all select 'XXFND_RECORD_CHANGED', 'This record was changed by someone else. Reload the page and try again.', -20001, 'Optimistic locking: the row changed since it was read.' from dual
       union all select 'XXFND_NOT_ALLOWED', 'You are not allowed to do this.', -20002, 'Generic authorisation failure.' from dual) s
   on (d.message_code = s.code and d.language_code = 'en')
 when not matched then insert (message_code, language_code, message_text, error_number, description)
                       values (s.code, 'en', s.txt, s.num, s.dsc);
-- release 77: no retention policy is seeded (the business keeps every record); the release 76 seed is taken back
-- when nobody changed it since
delete from xxfnd_retention_policies
 where table_name = 'XXFND_ERROR_LOG' and jurisdiction is null and retention_years = 1
   and action_at_expiry = 'FLAG_FOR_REVIEW' and object_version_number = 1;
commit;
