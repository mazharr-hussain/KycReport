
--------------------------------------------------------------------------------
-- One questions-and-answers history (release 82): the questions and answers of the APEX "Request Information" of a
-- task and of the RFI rounds of a record, together, for the application screens. One row per message.
--   RECORD_KEY = the task's detail key (approval tasks) or the RFI's record key (PK1_VALUE).
--------------------------------------------------------------------------------
create or replace view xxfnd_qa_history_v as
select m.application_code, m.source_code, m.source_type, m.record_key, m.source_id, m.message_text, m.author,
       m.message_date
  from table(xxfnd_workflow_pkg.task_messages) m
union all
select r.application_code, r.entity_name, 'RFI_QUESTION', r.pk1_value, r.rfi_id,
       q.question, q.asked_by, cast(q.asked_date as timestamp with time zone)
  from xxfnd_rfis r
  join xxfnd_rfi_rounds q on q.rfi_id = r.rfi_id
union all
select r.application_code, r.entity_name, 'RFI_ANSWER', r.pk1_value, r.rfi_id,
       dbms_lob.substr(q.response_text, 4000, 1), q.responded_by, cast(q.responded_date as timestamp with time zone)
  from xxfnd_rfis r
  join xxfnd_rfi_rounds q on q.rfi_id = r.rfi_id
 where q.response_text is not null;
comment on table xxfnd_qa_history_v is 'Release 82: questions and answers of a record in one list - APEX task comments (Request Information, Submit Information, decisions) and the questions and answers of its requests for information.';
