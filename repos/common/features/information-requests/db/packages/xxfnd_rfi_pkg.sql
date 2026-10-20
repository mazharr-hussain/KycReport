
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

create or replace package body xxfnd_rfi_pkg as

    function hash_token(p_token in varchar2) return varchar2 is
    begin
        return rawtohex(dbms_crypto.hash(utl_i18n.string_to_raw(p_token, 'AL32UTF8'), dbms_crypto.hash_sh256));
    end hash_token;

    function app_code(p_application_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type;
    begin
        if p_application_code is not null then
            -- release 88 (C10): an application raises RFIs for its own records only (COMMON for any application)
            return xxfnd_application_pkg.registered_code(p_application_code);
        end if;
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS')) or apex_application_id = to_number(v('APP_ID'));
        return nvl(l_code, 'COMMON');
    end app_code;

    -- release 84: the RFI is read and changed in trusted mode once the caller is authorised: the person asked answers,
    -- the person who raised it (or anyone its data security allows, or a workflow administrator) reviews it
    function locked(p_rfi_id in number) return xxfnd_rfis%rowtype is
        l_rfi xxfnd_rfis%rowtype;
    begin
        select * into l_rfi from xxfnd_rfis where rfi_id = p_rfi_id for update;
        return l_rfi;
    exception
        when no_data_found then
            raise_application_error(-20507, 'Request for information ' || p_rfi_id || ' does not exist.');
    end locked;

    procedure assert_reviewer(p_rfi_id in number) is
        l_seen  pls_integer;
        l_maker xxfnd_rfis.created_by%type;
    begin
        select count(*) into l_seen from xxfnd_rfis where rfi_id = p_rfi_id;   -- under the caller's data security
        xxfnd_vpd_pkg.begin_trusted;
        select max(created_by) into l_maker from xxfnd_rfis where rfi_id = p_rfi_id;
        xxfnd_vpd_pkg.end_trusted;
        if l_seen = 0 and upper(nvl(l_maker, '#')) <> upper(xxfnd_util_pkg.current_user)
           and xxfnd_privilege_pkg.has_privilege_yn('WORKFLOW_MONITOR', 'MANAGE') = 'N' then
            raise_application_error(-20511, 'You may not review this request for information.');
        end if;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end assert_reviewer;

    function new_token(p_rfi_id in number, p_due_date in date) return varchar2 is
        l_token varchar2(64) := lower(rawtohex(dbms_crypto.randombytes(32)));
        l_hash  varchar2(128) := hash_token(l_token);
    begin
        update xxfnd_rfis
           set response_token_hash = l_hash,
               token_expiry_date   = cast(nvl(p_due_date, trunc(sysdate) + 14) + 1 as timestamp)
         where rfi_id = p_rfi_id;
        return l_token;
    end new_token;

    -- release 84: the tasks of the RFI belong to the COMMON workflow process RFI
    procedure complete_task(p_task_definition in varchar2, p_rfi_id in number) is
    begin
        xxfnd_workflow_pkg.complete_open(p_task_definition, to_char(p_rfi_id),
                                         p_application_id => xxfnd_workflow_pkg.common_application_id);
    end complete_task;

    -- release 84: an answer (or the end of the wait) moves the RFI workflow on: an outside person's answer continues
    -- the workflow's wait for it
    procedure continue_wait(p_rfi in xxfnd_rfis%rowtype) is
        l_params wwv_flow_global.vc_map;
    begin
        if p_rfi.workflow_id is not null and xxfnd_workflow_pkg.is_running(p_rfi.workflow_id) = 'Y' then
            for a in (select 1 from apex_workflow_activities
                       where workflow_id = p_rfi.workflow_id and static_id = 'WAIT_ANSWER'
                         and end_time is null) loop
                apex_workflow.continue_activity(p_instance_id => p_rfi.workflow_id, p_static_id => 'WAIT_ANSWER',
                                                p_activity_params => l_params);
            end loop;
        end if;
    end continue_wait;

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
                         p_token               out varchar2) is
        l_rule  varchar2(100);
        l_users varchar2(4000);
        l_type_on varchar2(1);
        l_wf    number;
        l_app xxfnd_applications.application_code%type := app_code(p_application_code);
        -- release 82: the requester is the default recipient
        l_recipient varchar2(255) := case when p_recipient_type = 'USER'
                                          then upper(coalesce(p_recipient_user_name, p_requester)) end;
    begin
        xxfnd_lookup_pkg.assert_lookup('RFI_CATEGORY', p_rfi_category, 'RFI category');
        select max(enabled_flag) into l_type_on from xxfnd_approval_types where approval_type_code = upper(p_approval_type);
        if p_recipient_type = 'USER' and l_recipient is null and nvl(l_type_on, 'N') = 'N' then
            raise_application_error(-20509, 'Choose who provides the information.');
        end if;
        if p_due_date is not null and p_due_date < trunc(sysdate) then
            raise_application_error(-20501, 'The due date cannot be in the past.');
        end if;
        insert into xxfnd_rfis (application_code, entity_name, pk1_value, recipient_type, recipient_user_name,
                                recipient_name, recipient_email, recipient_reference, rfi_category, description,
                                continue_other_work_flag, rfi_status, due_date, language_code)
        values (l_app, p_entity_name, p_pk1_value, p_recipient_type, l_recipient,
                p_recipient_name, p_recipient_email, p_recipient_reference, p_rfi_category, p_description,
                nvl(p_continue_other_work, 'Y'),
                case when nvl(p_continue_other_work, 'Y') = 'Y' then 'WAITING_FOR_INFORMATION' else 'ON_HOLD_PENDING' end,
                p_due_date, nvl(p_language, 'en'))
        returning rfi_id into p_rfi_id;
        insert into xxfnd_rfi_rounds (rfi_id, round_no, question, asked_by)
        values (p_rfi_id, 1, p_description, xxfnd_util_pkg.current_user);
        if p_approval_type is not null and l_type_on = 'Y' then
            l_rule  := xxfnd_approval_rule_pkg.start_approval(p_approval_type, to_char(p_rfi_id), p_attributes, p_requester);
            l_users := xxfnd_approval_rule_pkg.current_approvers(p_approval_type, to_char(p_rfi_id));
            update xxfnd_rfis
               set approval_type_code = upper(p_approval_type),
                   recipient_user_name = case when instr(l_users, ',') = 0 then l_users else recipient_user_name end
             where rfi_id = p_rfi_id;
        end if;
        -- an outside person answers through the e-mailed one-time link (no account)
        if p_recipient_type <> 'USER' then
            p_token := new_token(p_rfi_id, p_due_date);
        end if;
        -- release 84: the COMMON workflow process RFI asks, waits and has the answer reviewed (workflow switch of the
        -- application's RFI process; p_with_tasks N = the application collects the answer itself)
        if nvl(p_with_tasks, 'Y') = 'Y'
           and xxfnd_workflow_pkg.workflow_enabled(xxfnd_workflow_pkg.c_rfi_process, l_app) = 'Y' then
            l_wf := xxfnd_workflow_pkg.start_process(p_static_id        => xxfnd_workflow_pkg.c_rfi_process,
                                                     p_detail_pk        => to_char(p_rfi_id),
                                                     p_application_id   => xxfnd_workflow_pkg.common_application_id,
                                                     p_application_code => l_app);
            update xxfnd_rfis set workflow_id = l_wf where rfi_id = p_rfi_id;
        end if;
    end create_rfi;

    function recipient(p_rfi_id in number) return varchar2 is
        l_user xxfnd_rfis.recipient_user_name%type;
        l_type xxfnd_rfis.approval_type_code%type;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(recipient_user_name), max(approval_type_code) into l_user, l_type from xxfnd_rfis where rfi_id = p_rfi_id;
        xxfnd_vpd_pkg.end_trusted;
        if l_type is not null then
            return xxfnd_approval_rule_pkg.current_approvers(l_type, to_char(p_rfi_id));
        end if;
        return l_user;
    end recipient;

    function rfi_tokens(p_rfi in xxfnd_rfis%rowtype) return clob is
        l_json json_object_t := json_object_t();
    begin
        l_json.put('RFI_NUMBER',   p_rfi.rfi_number);
        l_json.put('DESCRIPTION',  p_rfi.description);
        l_json.put('DUE_DATE',     nvl(to_char(p_rfi.due_date, 'DD-Mon-YYYY'), '-'));
        l_json.put('CONTACT_NAME', nvl(p_rfi.recipient_name, 'Sir/Madam'));
        l_json.put('RECORD_KEY',   p_rfi.pk1_value);
        return l_json.to_clob;
    end rfi_tokens;

    -- release 84: the answer is kept first, then the workflow moves on (the next provider, or the review)
    procedure record_answer(p_rfi in xxfnd_rfis%rowtype, p_response_text in clob, p_by in varchar2) is
        l_next varchar2(1) := 'N';
    begin
        update xxfnd_rfis
           set response_text = p_response_text, responded_date = systimestamp, rfi_status = 'RESPONDED',
               response_token_hash = null, token_expiry_date = null
         where rfi_id = p_rfi.rfi_id;
        merge into xxfnd_rfi_rounds d
        using (select p_rfi.rfi_id rfi_id, p_rfi.round_no round_no from dual) s
           on (d.rfi_id = s.rfi_id and d.round_no = s.round_no)
         when matched then update set d.response_text = case when d.response_text is null then p_response_text
                                                             else d.response_text || chr(10) || p_by || ': ' || p_response_text end,
                                      d.responded_by = case when d.responded_by is null then p_by
                                                            else d.responded_by || ', ' || p_by end,
                                      d.responded_date = systimestamp
         when not matched then insert (rfi_id, round_no, question, response_text, responded_by, responded_date)
                               values (s.rfi_id, s.round_no, p_rfi.description, p_response_text, p_by, systimestamp);
        -- providers from the Approval Setup answer in turn: the workflow asks the next one (IS_WAITING)
        if p_rfi.approval_type_code is not null then
            l_next := xxfnd_approval_rule_pkg.next_step(p_rfi.approval_type_code, to_char(p_rfi.rfi_id));
            if l_next = 'Y' then
                update xxfnd_rfis set rfi_status = 'WAITING_FOR_INFORMATION' where rfi_id = p_rfi.rfi_id;
            end if;
        end if;
        if l_next = 'N' then
            xxfnd_notify_pkg.raise_event(p_event_code       => xxfnd_notify_pkg.event_for('RFI_ANSWERED'),
                                         p_application_code => p_rfi.application_code,
                                         p_process_code     => xxfnd_workflow_pkg.c_rfi_process,
                                         p_workflow_id      => p_rfi.workflow_id,
                                         p_detail_pk        => to_char(p_rfi.rfi_id),
                                         p_tokens           => rfi_tokens(p_rfi));
        end if;
    end record_answer;

    procedure respond(p_rfi_id in number, p_response_text in clob) is
        l_rfi xxfnd_rfis%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;   -- release 84: the person asked answers (checked below)
        l_rfi := locked(p_rfi_id);
        if l_rfi.recipient_type <> 'USER'
           or instr(',' || recipient(p_rfi_id) || ',', ',' || upper(xxfnd_util_pkg.current_user) || ',') = 0 then
            raise_application_error(-20502, 'This request for information is not addressed to you.');
        end if;
        if l_rfi.rfi_status not in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING', 'RESPONDED') then
            raise_application_error(-20503, 'This request for information is closed.');
        end if;
        record_answer(l_rfi, p_response_text, xxfnd_util_pkg.current_user);
        complete_task('RFI_RESPONSE', p_rfi_id);   -- the workflow goes on
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end respond;

    function respond_by_token(p_token in varchar2, p_response_text in clob) return number is
        l_rfi  xxfnd_rfis%rowtype;
        l_hash varchar2(128) := hash_token(p_token);
    begin
        -- the caller is an anonymous person (APP_USER nobody): the token is the authorisation, so data security is
        -- bypassed for this call only
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select * into l_rfi from xxfnd_rfis where response_token_hash = l_hash for update;
        exception
            when no_data_found then
                raise_application_error(-20504, 'This link is not valid.');
        end;
        if l_rfi.token_expiry_date < systimestamp
           or l_rfi.rfi_status not in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING') then
            raise_application_error(-20505, 'This link has expired or the request is closed.');
        end if;
        record_answer(l_rfi, p_response_text, nvl(l_rfi.recipient_name, l_rfi.recipient_email));
        continue_wait(l_rfi);   -- release 84: the workflow stops waiting and has the answer reviewed
        xxfnd_vpd_pkg.end_trusted;
        return l_rfi.rfi_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end respond_by_token;

    function question_by_token(p_token in varchar2) return varchar2 is
        l_question xxfnd_rfis.description%type;
        l_hash     varchar2(128);
    begin
        if p_token is null then
            return null;
        end if;
        l_hash := hash_token(p_token);
        xxfnd_vpd_pkg.begin_trusted;
        select max(description) into l_question
          from xxfnd_rfis
         where response_token_hash = l_hash
           and token_expiry_date >= systimestamp
           and rfi_status in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING');
        xxfnd_vpd_pkg.end_trusted;
        return l_question;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end question_by_token;

    procedure close_round(p_rfi_id in number, p_round_no in number, p_outcome in varchar2, p_notes in varchar2) is
    begin
        update xxfnd_rfi_rounds
           set review_outcome = p_outcome, review_notes = p_notes, reviewed_by = xxfnd_util_pkg.current_user,
               reviewed_date = systimestamp
         where rfi_id = p_rfi_id and round_no = p_round_no;
    end close_round;

    function ask_again(p_rfi_id in number, p_question in varchar2) return varchar2 is
        l_rfi   xxfnd_rfis%rowtype;
        l_token varchar2(64);
    begin
        if trim(p_question) is null then
            raise_application_error(-20508, 'Enter the question to ask again.');
        end if;
        assert_reviewer(p_rfi_id);
        xxfnd_vpd_pkg.begin_trusted;
        l_rfi := locked(p_rfi_id);
        if l_rfi.rfi_status in ('RESOLVED', 'REJECTED_RETURNED', 'CANCELLED') then
            raise_application_error(-20503, 'This request for information is closed.');
        end if;
        close_round(p_rfi_id, l_rfi.round_no, 'ASKED_AGAIN', p_question);
        update xxfnd_rfis
           set round_no = round_no + 1, description = substr(p_question, 1, 4000), rfi_status = 'WAITING_FOR_INFORMATION',
               response_text = null, responded_date = null
         where rfi_id = p_rfi_id;
        insert into xxfnd_rfi_rounds (rfi_id, round_no, question, asked_by)
        values (p_rfi_id, l_rfi.round_no + 1, substr(p_question, 1, 4000), xxfnd_util_pkg.current_user);
        if l_rfi.approval_type_code is not null then
            -- the same providers again, from the first one
            update xxfnd_approval_txns
               set approval_status = 'IN_PROGRESS',
                   current_seq = (select min(step_seq) from xxfnd_approval_txn_steps
                                   where approval_type_code = l_rfi.approval_type_code and txn_id = to_char(p_rfi_id))
             where approval_type_code = l_rfi.approval_type_code and txn_id = to_char(p_rfi_id);
        end if;
        if l_rfi.recipient_type <> 'USER' then
            l_token := new_token(p_rfi_id, l_rfi.due_date);
        end if;
        -- release 84: the review task completes; the workflow sees the RFI waiting and asks again (the loop)
        complete_task('RFI_REVIEW', p_rfi_id);
        xxfnd_vpd_pkg.end_trusted;
        return l_token;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end ask_again;

    procedure resolve(p_rfi_id in number, p_status in varchar2, p_notes in varchar2) is
        l_rfi    xxfnd_rfis%rowtype;
        l_review pls_integer;
    begin
        if p_status not in ('RESOLVED', 'REJECTED_RETURNED', 'CANCELLED', 'ON_HOLD_INVESTIGATION') then
            raise_application_error(-20506, 'Status ' || p_status || ' cannot be set here.');
        end if;
        assert_reviewer(p_rfi_id);
        xxfnd_vpd_pkg.begin_trusted;
        l_rfi := locked(p_rfi_id);
        update xxfnd_rfis
           set rfi_status = p_status, resolution_notes = p_notes,
               resolved_date = case when p_status <> 'ON_HOLD_INVESTIGATION' then systimestamp end,
               response_token_hash = case when p_status <> 'ON_HOLD_INVESTIGATION' then null else response_token_hash end
         where rfi_id = p_rfi_id;
        if p_status = 'ON_HOLD_INVESTIGATION' then
            xxfnd_vpd_pkg.end_trusted;
            return;
        end if;
        close_round(p_rfi_id, l_rfi.round_no, p_status, p_notes);
        -- release 84: a decided review ends the workflow; resolved or cancelled before the review, the workflow ends
        select count(*) into l_review from apex_tasks
         where task_def_static_id = 'RFI_REVIEW' and detail_pk = to_char(p_rfi_id)
           and state_code in ('UNASSIGNED', 'ASSIGNED');
        if p_status <> 'CANCELLED' and l_review > 0 then
            complete_task('RFI_REVIEW', p_rfi_id);
        else
            xxfnd_workflow_pkg.end_process(l_rfi.workflow_id);
        end if;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end resolve;

    procedure send_email(p_rfi_id in number, p_response_url in varchar2 default null, p_token in varchar2 default null) is
        l_rfi    xxfnd_rfis%rowtype;
        l_json   json_object_t;
        l_before number;
    begin
        xxfnd_vpd_pkg.begin_trusted;   -- the caller raised or reviews it (checked by the calling step)
        select * into l_rfi from xxfnd_rfis where rfi_id = p_rfi_id;
        xxfnd_vpd_pkg.end_trusted;
        l_json := json_object_t.parse(rfi_tokens(l_rfi));
        if p_response_url is not null then
            l_json.put('LINK', p_response_url);          -- the application's own answer page
        end if;
        l_json.put('RESPONSE_TOKEN', p_token);           -- the COMMON Provide Information page (event link)
        select nvl(max(notification_id), 0) into l_before from xxfnd_notifications;
        -- release 84: who is told and how comes from the rules of event RFI_RAISED
        xxfnd_notify_pkg.raise_event(p_event_code       => xxfnd_notify_pkg.event_for('RFI_RAISED'),
                                     p_application_code => l_rfi.application_code,
                                     p_process_code     => xxfnd_workflow_pkg.c_rfi_process,
                                     p_workflow_id      => l_rfi.workflow_id,
                                     p_detail_pk        => to_char(l_rfi.rfi_id),
                                     p_tokens           => l_json.to_clob);
        -- release 74 (R27): an e-mail to an outside person is kept with the record's communications; the one-time
        -- link is masked (only its hash is stored with the RFI)
        if l_rfi.recipient_type <> 'USER' then
            for n in (select subject, message_text, email_address, mail_id from xxfnd_notifications
                       where notification_id > l_before and detail_pk = to_char(l_rfi.rfi_id)
                         and user_name is null and status_code = 'SENT' and mail_id is not null) loop
                xxfnd_notify_pkg.record_sent(l_rfi.application_code, l_rfi.entity_name, l_rfi.pk1_value, n.email_address,
                                             n.subject, n.message_text, l_rfi.rfi_id, n.mail_id);
            end loop;
        end if;
    end send_email;

    function open_count(p_entity_name in varchar2, p_pk1_value in varchar2) return number is
        l_n number;
    begin
        select count(*) into l_n from xxfnd_rfis
         where entity_name = p_entity_name and pk1_value = p_pk1_value
           and rfi_status not in ('RESOLVED', 'REJECTED_RETURNED', 'CANCELLED');
        return l_n;
    end open_count;

    procedure sync_sequences is
        l_max number;
    begin
        select nvl(max(rfi_id), 0) into l_max from xxfnd_rfis;
        execute immediate 'alter sequence xxfnd_rfi_s restart start with ' || (l_max + 1);
        select nvl(max(to_number(regexp_substr(rfi_number, '\d+$'))), 0) into l_max from xxfnd_rfis;
        execute immediate 'alter sequence xxfnd_rfi_number_s restart start with ' || (l_max + 1);
    end sync_sequences;

    ---------------------------------------------------------------- the RFI workflow (release 84)
    function is_external(p_rfi_id in number) return varchar2 is
        l_type xxfnd_rfis.recipient_type%type;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(recipient_type) into l_type from xxfnd_rfis where rfi_id = to_number(p_rfi_id);
        xxfnd_vpd_pkg.end_trusted;
        return case when l_type = 'USER' then 'N' else 'Y' end;
    end is_external;

    function is_waiting(p_rfi_id in number) return varchar2 is
        l_status xxfnd_rfis.rfi_status%type;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(rfi_status) into l_status from xxfnd_rfis where rfi_id = to_number(p_rfi_id);
        xxfnd_vpd_pkg.end_trusted;
        return case when l_status in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING') then 'Y' else 'N' end;
    end is_waiting;

    function answer_wait(p_rfi_id in number) return timestamp with time zone is
        l_expiry timestamp;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(token_expiry_date) into l_expiry from xxfnd_rfis where rfi_id = to_number(p_rfi_id);
        xxfnd_vpd_pkg.end_trusted;
        return from_tz(nvl(l_expiry, cast(trunc(sysdate) + 15 as timestamp)), sessiontimezone);
    end answer_wait;

    function reviewers(p_rfi_id in number) return varchar2 is
        l_user xxfnd_rfis.created_by%type;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(created_by) into l_user from xxfnd_rfis where rfi_id = to_number(p_rfi_id);
        xxfnd_vpd_pkg.end_trusted;
        return upper(l_user);
    end reviewers;

    procedure task_created(p_task_id in number) is
    begin
        for t in (select task_def_static_id, detail_pk from apex_tasks where task_id = p_task_id) loop
            update xxfnd_rfis
               set response_task_id = case when t.task_def_static_id = 'RFI_RESPONSE' then p_task_id else response_task_id end,
                   review_task_id   = case when t.task_def_static_id = 'RFI_REVIEW' then p_task_id else review_task_id end
             where rfi_id = to_number(t.detail_pk);
        end loop;
    end task_created;

    function task_due_date(p_rfi_id in number, p_task_definition in varchar2) return timestamp with time zone is
        l_due date;
    begin
        if upper(p_task_definition) = 'RFI_RESPONSE' then
            select max(due_date) into l_due from xxfnd_rfis where rfi_id = p_rfi_id;
        end if;
        if l_due is not null then
            return from_tz(cast(trunc(l_due) + 1 - 1 / 86400 as timestamp), sessiontimezone);
        end if;
        -- release 94 (UI issue 8): the deadline of the current Approval Setup step, else the process deadline
        for r in (select approval_type_code from xxfnd_rfis where rfi_id = p_rfi_id and approval_type_code is not null) loop
            return coalesce(xxfnd_approval_rule_pkg.step_due_date(r.approval_type_code, to_char(p_rfi_id)),
                            xxfnd_workflow_pkg.due_date(upper(p_task_definition)));
        end loop;
        return xxfnd_workflow_pkg.due_date(upper(p_task_definition));
    end task_due_date;

    procedure task_values(p_task_id in number, p_rfi_id out number, p_rfi_number out varchar2, p_status out varchar2,
                          p_asked out varchar2, p_due out varchar2, p_record out varchar2, p_raised_by out varchar2) is
        l_pk varchar2(4000) := xxfnd_workflow_pkg.task_record(p_task_id);
    begin
        if l_pk is null then
            return;   -- not the user's task
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        for r in (select r.rfi_id, r.rfi_number, nvl(l.meaning, r.rfi_status) status,
                         coalesce(r.recipient_user_name, r.recipient_name, r.recipient_email) asked,
                         to_char(r.due_date, 'DD-Mon-YYYY') due,
                         r.application_code || ' - ' || r.entity_name || ' ' || r.pk1_value record_, r.created_by
                    from xxfnd_rfis r
                    left join xxfnd_lookup_values l on l.lookup_type = 'RFI_STATUS' and l.lookup_code = r.rfi_status
                   where r.rfi_id = to_number(l_pk)) loop
            p_rfi_id := r.rfi_id; p_rfi_number := r.rfi_number; p_status := r.status; p_asked := r.asked;
            p_due := r.due; p_record := r.record_; p_raised_by := r.created_by;
        end loop;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end task_values;

    function task_messages(p_task_id in number) return xxfnd_qa_tab pipelined is
        l_pk   varchar2(4000) := xxfnd_workflow_pkg.task_record(p_task_id);
        l_rows xxfnd_qa_tab := xxfnd_qa_tab();
    begin
        if l_pk is null then
            return;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select xxfnd_qa_row(r.application_code, 'ROUND ' || q.round_no, m.kind, r.pk1_value, r.rfi_id,
                                m.text, m.author, cast(m.at as timestamp with time zone))
              bulk collect into l_rows
              from xxfnd_rfis r
              join xxfnd_rfi_rounds q on q.rfi_id = r.rfi_id
              cross apply (select 'QUESTION' kind, q.question text, q.asked_by author, q.asked_date at, 1 seq from dual
                           union all
                           select 'ANSWER', dbms_lob.substr(q.response_text, 4000, 1), q.responded_by, q.responded_date, 2
                             from dual where q.response_text is not null
                           union all
                           select 'REVIEW: ' || q.review_outcome, q.review_notes, q.reviewed_by, q.reviewed_date, 3
                             from dual where q.review_outcome is not null) m
             where r.rfi_id = to_number(l_pk)
             order by q.round_no, m.seq;
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        for i in 1 .. l_rows.count loop
            pipe row (l_rows(i));
        end loop;
        return;
    end task_messages;

end xxfnd_rfi_pkg;
/
