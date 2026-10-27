
-- messages (administrators may change the texts; existing rows are kept)
merge into xxfnd_messages d
using (select 'XXFND_APPROVAL_NO_RULE' code, 'No approval rule applies to this {1} transaction. Ask the administrator to add a rule in Approval Setup.' txt, -20531 num from dual
       union all select 'XXFND_APPROVAL_NOT_IN_PROGRESS', 'This approval is not in progress.', -20532 from dual
       union all select 'XXFND_APPROVAL_ADD_NOT_ALLOWED', 'Only the requester or the current approver can add an approver.', -20533 from dual
       union all select 'XXFND_APPROVAL_APPROVER_REQUIRED', 'Choose the role or the user to add as approver.', -20534 from dual
       -- release 76 (A-11)
       union all select 'XXFND_APPROVAL_NO_APPROVER', 'The approval step "{1}" has no approver: no active user holds the role {2}. Ask the administrator to give the role to a user or to change the rule in Approval Setup.', -20535 from dual) s
   on (d.message_code = s.code and d.language_code = 'en')
 when not matched then insert (message_code, language_code, message_text, error_number) values (s.code, 'en', s.txt, s.num);
commit;
