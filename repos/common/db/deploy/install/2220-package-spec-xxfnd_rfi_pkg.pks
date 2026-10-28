
create or replace package xxfnd_rfi_pkg authid definer as
    -- Raises an RFI (round 1). p_recipient_type USER (p_recipient_user_name) or EXTERNAL (p_recipient_email,
    -- p_recipient_name). For an external person a one-time token is returned for the e-mail link only.
    procedure create_rfi(p_entity_name         in varchar2,
                         p_pk1_value           in varchar2,
                         p_recipient_type      in varchar2,
                         p_rfi_category        in varchar2,
                         p_description         in varchar2,
                         p_continue_other_work in varchar2 default 'Y',
                         p_due_date            in date     default null,
                         p_recipient_user_name in varchar2 default null,
                         p_recipient_name      in varchar2 default null,
                         p_recipient_email     in varchar2 default null,
                         p_recipient_reference in varchar2 default null,
                         p_application_code    in varchar2 default null,
                         p_with_tasks          in varchar2 default 'Y',
                         p_approval_type       in varchar2 default null,
                         p_attributes          in apex_t_varchar2 default null,
                         p_requester           in varchar2 default null,
                         p_language            in varchar2 default null,
                         p_rfi_id              out number,
                         p_token               out varchar2);
    -- Release 82: a USER recipient left empty is the requester (p_requester) - the default recipient of an RFI.
    -- p_language: the language of the e-mail to an EXTERNAL recipient (default English); a user gets their own.
    -- p_approval_type: who provides the information comes from that Approval Setup type (p_attributes, p_requester)
    -- while the type is enabled (a disabled type, e.g. CASE_RFI, is ignored: the chosen recipient answers);
    -- each provider answers in turn (ad-hoc providers can be added), then the answer is reviewed.
    -- Release 82: the RFI process of the application (Process Catalogue): workflow off = no response task; e-mail off
    -- = no e-mail.
    -- p_with_tasks N: the application collects the answer in its own way (e.g. the requester resubmits a returned
    -- request) and resolves the RFI itself; no response task is created.
    -- Participant of the RFI_RESPONSE task: the user the RFI is addressed to.
    function recipient(p_rfi_id in number) return varchar2;
    -- The answer of the user it is addressed to.
    procedure respond(p_rfi_id in number, p_response_text in clob);
    -- The answer of an external person through the e-mailed link; returns the RFI ID.
    function respond_by_token(p_token in varchar2, p_response_text in clob) return number;
    -- The reviewer asks again (the loop): a new round with the question; the recipient answers again.
    -- Returns a new token for an external person (null for a user).
    function ask_again(p_rfi_id in number, p_question in varchar2) return varchar2;
    -- The reviewer closes the round: RESOLVED, REJECTED_RETURNED, CANCELLED or ON_HOLD_INVESTIGATION.
    procedure resolve(p_rfi_id in number, p_status in varchar2, p_notes in varchar2);
    -- Tells the recipient (release 84: notification event RFI_RAISED - its rules say who and on which channel; an
    -- outside person gets the e-mail with the one-time link P_TOKEN to the COMMON page Provide Information, or
    -- P_RESPONSE_URL when the application gives its own page). E-mail switches apply.
    procedure send_email(p_rfi_id in number, p_response_url in varchar2 default null, p_token in varchar2 default null);
    ---------------------------------------------------------------- the RFI workflow (release 84)
    -- Y when the RFI is addressed to an outside person (the workflow waits for the answer through the link).
    function is_external(p_rfi_id in number) return varchar2;
    -- Y while the RFI waits for an answer (a further provider, or asked again): the workflow goes back to the answer.
    function is_waiting(p_rfi_id in number) return varchar2;
    -- Until when the workflow waits for an outside person: the link's expiry (then the reviewer decides).
    function answer_wait(p_rfi_id in number) return timestamp with time zone;
    -- Who reviews the answer: the person who raised the RFI.
    function reviewers(p_rfi_id in number) return varchar2;
    -- Task definition action "on create" of RFI_RESPONSE / RFI_REVIEW: keeps the task on the RFI.
    procedure task_created(p_task_id in number);
    -- The question an outside person sees on the public page (null when the link is not valid any more).
    function question_by_token(p_token in varchar2) return varchar2;
    -- The task page (COMMON 143): the RFI of a task the signed-in user takes part in (XXFND_WORKFLOW_PKG.TASK_RECORD),
    -- read whatever the user's data security on XXFND_RFIS (the task authorises them).
    procedure task_values(p_task_id in number, p_rfi_id out number, p_rfi_number out varchar2, p_status out varchar2,
                          p_asked out varchar2, p_due out varchar2, p_record out varchar2, p_raised_by out varchar2);
    -- Release 88 (C5): the due date of a task of the RFI (task definitions RFI_RESPONSE / RFI_REVIEW): the RFI's own due
    -- date (end of that day) for the answer, else the due days of the task setting (Task Settings), else none.
    function task_due_date(p_rfi_id in number, p_task_definition in varchar2) return timestamp with time zone;
    -- Its questions, answers and reviews, one row per message (round order).
    function task_messages(p_task_id in number) return xxfnd_qa_tab pipelined;
    -- Open RFIs of a record (not resolved / cancelled).
    function open_count(p_entity_name in varchar2, p_pk1_value in varchar2) return number;
    -- After RFIs were copied in with their IDs and numbers: the sequences continue after them.
    procedure sync_sequences;
end xxfnd_rfi_pkg;
/
