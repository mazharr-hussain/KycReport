
-- Release 82: one message of the questions-and-answers history (XXFND_QA_HISTORY_V, script 24)
create or replace type xxfnd_qa_row force as object (
    application_code  varchar2(30),
    source_code       varchar2(255),
    source_type       varchar2(30),
    record_key        varchar2(4000),
    source_id         number,
    message_text      varchar2(4000),
    author            varchar2(255),
    message_date      timestamp with time zone
);
/
