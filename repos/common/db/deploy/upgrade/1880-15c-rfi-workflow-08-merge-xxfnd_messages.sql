
-- messages of the RFI workflow (administrators may change the texts; existing rows are kept)
merge into xxfnd_messages d
using (select 'XXFND_RFI_QUESTION_REQUIRED' code, 'Enter the new question in Notes / New Question before asking again.' txt, -20508 num from dual) s
   on (d.message_code = s.code and d.language_code = 'en')
 when not matched then insert (message_code, language_code, message_text, error_number) values (s.code, 'en', s.txt, s.num);
commit;
