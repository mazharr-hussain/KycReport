--------------------------------------------------------------------------------
-- 15c Request for Information workflow (release 74). COMMON only (XXFUSION); every application uses it.
--   An application raises an RFI on one of its records (entity + key) to a person: a user (answers in My Tasks,
--   RFI_RESPONSE task) or an external person (answers through a one-time e-mailed link). The answer is reviewed
--   (RFI_REVIEW task); the reviewer resolves it or asks again - the same RFI loops, one round per question
--   (XXFND_RFI_ROUNDS) - until it is resolved or cancelled. The application keeps its own screens and checks and
--   gives the recipient (e.g. KYC: a contact person of the party).
--   KYC's earlier RFIs (XXCMP_RFIS) are copied here once with their numbers (KYC script 16k); XXCMP_RFIS itself is
--   kept unchanged as history.
-- Idempotent (CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
declare
    l_n pls_integer;
begin
    if xxfnd_ddl_pkg.create_table('XXFND_RFIS', q'~create table xxfnd_rfis (
    rfi_id                   number         not null,
    rfi_number               varchar2(30)   not null,
    application_code         varchar2(30)   not null,
    entity_name              varchar2(60)   not null,
    pk1_value                varchar2(150)  not null,
    recipient_type           varchar2(30)   not null,
    recipient_user_name      varchar2(255),
    recipient_name           varchar2(360),
    recipient_email          varchar2(320),
    recipient_reference      varchar2(150),
    approval_type_code       varchar2(30),
    rfi_category             varchar2(30)   not null,
    description              varchar2(4000) not null,
    continue_other_work_flag varchar2(1)    default 'Y' not null,
    rfi_status               varchar2(30)   default 'WAITING_FOR_INFORMATION' not null,
    round_no                 number         default 1 not null,
    due_date                 date,
    response_token_hash      varchar2(128),
    token_expiry_date        timestamp,
    response_text            clob,
    responded_date           timestamp,
    resolved_date            timestamp,
    resolution_notes         varchar2(4000),
    response_task_id         number,
    review_task_id           number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_rfis_pk primary key (rfi_id),
    constraint xxfnd_rfis_uk1 unique (rfi_number),
    constraint xxfnd_rfis_ck1 check (recipient_type in ('USER', 'EXTERNAL')),
    constraint xxfnd_rfis_ck2 check (continue_other_work_flag in ('Y', 'N')),
    constraint xxfnd_rfis_ck3 check (rfi_status in
        ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING', 'RESPONDED', 'ON_HOLD_INVESTIGATION', 'RESOLVED',
         'REJECTED_RETURNED', 'CANCELLED')),
    constraint xxfnd_rfis_ck4 check ((recipient_type = 'USER' and recipient_user_name is not null)
                                  or (recipient_type = 'EXTERNAL' and (recipient_email is not null or recipient_reference is not null)))
)~') then
        xxfnd_ddl_pkg.run(q'~create index xxfnd_rfis_n1 on xxfnd_rfis (application_code, entity_name, pk1_value)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_rfis_n2 on xxfnd_rfis (upper(recipient_user_name))~');
        xxfnd_ddl_pkg.run(q'~create unique index xxfnd_rfis_u2 on xxfnd_rfis (response_token_hash)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_rfis is 'Requests for information of every application: one row per RFI; its questions and answers are in XXFND_RFI_ROUNDS.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_rfis.response_token_hash is 'SHA-256 hash of the one-time token e-mailed to an external person. The token itself is never stored.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_rfis.recipient_reference is 'The application''s own key of the recipient (KYC: party contact ID).'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_RFIS');
    -- who provides the information can come from the Approval Setup (e.g. CASE_RFI: the requester by default)
    xxfnd_ddl_pkg.add_column('XXFND_RFIS', 'APPROVAL_TYPE_CODE', 'varchar2(30)');

    if xxfnd_ddl_pkg.create_table('XXFND_RFI_ROUNDS', q'~create table xxfnd_rfi_rounds (
    rfi_id                 number         not null,
    round_no               number         not null,
    question               varchar2(4000) not null,
    asked_by               varchar2(255),
    asked_date             timestamp      default systimestamp not null,
    response_text          clob,
    responded_by           varchar2(255),
    responded_date         timestamp,
    review_outcome         varchar2(30),
    review_notes           varchar2(4000),
    reviewed_by            varchar2(255),
    reviewed_date          timestamp,
    constraint xxfnd_rfi_rounds_pk primary key (rfi_id, round_no),
    constraint xxfnd_rfi_rounds_fk1 foreign key (rfi_id) references xxfnd_rfis (rfi_id) on delete cascade,
    constraint xxfnd_rfi_rounds_ck1 check (review_outcome in ('RESOLVED', 'ASKED_AGAIN', 'REJECTED_RETURNED', 'CANCELLED'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_rfi_rounds is 'Each question of an RFI and its answer and review: the RFI loops (asked again) until resolved.'~');
    end if;

    xxfnd_ddl_pkg.ensure_sequence('XXFND_RFI_S', 'create sequence xxfnd_rfi_s');
    xxfnd_ddl_pkg.ensure_sequence('XXFND_RFI_NUMBER_S', 'create sequence xxfnd_rfi_number_s');

    -- data security: Common administrators see every RFI; each application adds its own roles' rules (KYC: 18e)
    merge into xxfnd_data_security_rules t
    using (select 'COMMON_ADMIN' r, 'XXFND_RFIS' tb, 'ALL_ROWS' ty from dual) s
       on (t.role_code = s.r and t.table_name = s.tb and t.rule_type = s.ty)
     when not matched then insert (role_code, table_name, rule_type) values (s.r, s.tb, s.ty);
    commit;
    xxfnd_schema_pkg.apply_policies;
end;
/

create or replace trigger xxfnd_rfis_bi
    before insert on xxfnd_rfis
    for each row
begin
    if :new.rfi_id is null then
        :new.rfi_id := xxfnd_rfi_s.nextval;
    end if;
    if :new.rfi_number is null then
        :new.rfi_number := 'RFI-' || lpad(xxfnd_rfi_number_s.nextval, 6, '0');
    end if;
end;
/

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
                         p_rfi_id              out number,
                         p_token               out varchar2);
    -- p_approval_type: who provides the information comes from that Approval Setup type (p_attributes, p_requester);
    -- each provider answers in turn (ad-hoc providers can be added), then the answer is reviewed.
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
    -- E-mails the recipient (template RFI_RAISED_INTERNAL / RFI_RAISED_EXTERNAL; e-mail switches apply).
    procedure send_email(p_rfi_id in number, p_response_url in varchar2 default null);
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
            return upper(p_application_code);
        end if;
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS')) or apex_application_id = to_number(v('APP_ID'));
        return nvl(l_code, 'COMMON');
    end app_code;

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

    procedure open_response(p_rfi_id in number) is
        l_task_id number;
    begin
        l_task_id := xxfnd_task_pkg.create_task('RFI_RESPONSE', to_char(p_rfi_id));
        update xxfnd_rfis set response_task_id = l_task_id where rfi_id = p_rfi_id;
    end open_response;

    procedure start_review(p_rfi_id in number) is
        l_task_id number;
    begin
        xxfnd_task_pkg.cancel_open('RFI_REVIEW', to_char(p_rfi_id));   -- a newer answer replaces the older one
        l_task_id := xxfnd_task_pkg.create_task('RFI_REVIEW', to_char(p_rfi_id));
        update xxfnd_rfis set review_task_id = l_task_id where rfi_id = p_rfi_id;
    end start_review;

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
                         p_rfi_id              out number,
                         p_token               out varchar2) is
        l_rule  varchar2(100);
        l_users varchar2(4000);
        l_app xxfnd_applications.application_code%type := app_code(p_application_code);
    begin
        xxfnd_util_pkg.assert_lookup('RFI_CATEGORY', p_rfi_category, 'RFI category');
        if p_due_date is not null and p_due_date < trunc(sysdate) then
            raise_application_error(-20501, 'The due date cannot be in the past.');
        end if;
        insert into xxfnd_rfis (application_code, entity_name, pk1_value, recipient_type, recipient_user_name,
                                recipient_name, recipient_email, recipient_reference, rfi_category, description,
                                continue_other_work_flag, rfi_status, due_date)
        values (l_app, p_entity_name, p_pk1_value, p_recipient_type, upper(p_recipient_user_name),
                p_recipient_name, p_recipient_email, p_recipient_reference, p_rfi_category, p_description,
                nvl(p_continue_other_work, 'Y'),
                case when nvl(p_continue_other_work, 'Y') = 'Y' then 'WAITING_FOR_INFORMATION' else 'ON_HOLD_PENDING' end,
                p_due_date)
        returning rfi_id into p_rfi_id;
        insert into xxfnd_rfi_rounds (rfi_id, round_no, question, asked_by)
        values (p_rfi_id, 1, p_description, xxfnd_util_pkg.current_user);
        if p_approval_type is not null then
            l_rule  := xxfnd_approval_rule_pkg.start_approval(p_approval_type, to_char(p_rfi_id), p_attributes, p_requester);
            l_users := xxfnd_approval_rule_pkg.current_approvers(p_approval_type, to_char(p_rfi_id));
            update xxfnd_rfis
               set approval_type_code = upper(p_approval_type),
                   recipient_user_name = case when instr(l_users, ',') = 0 then l_users else recipient_user_name end
             where rfi_id = p_rfi_id;
        end if;
        -- a user answers in My Tasks; an external person through the e-mailed link (no account, no task)
        if p_recipient_type = 'USER' then
            if nvl(p_with_tasks, 'Y') = 'Y' then
                open_response(p_rfi_id);
            end if;
        else
            p_token := new_token(p_rfi_id, p_due_date);
        end if;
    end create_rfi;

    function recipient(p_rfi_id in number) return varchar2 is
        l_user xxfnd_rfis.recipient_user_name%type;
        l_type xxfnd_rfis.approval_type_code%type;
    begin
        select max(recipient_user_name), max(approval_type_code) into l_user, l_type from xxfnd_rfis where rfi_id = p_rfi_id;
        if l_type is not null then
            return xxfnd_approval_rule_pkg.current_approvers(l_type, to_char(p_rfi_id));
        end if;
        return l_user;
    end recipient;

    procedure record_answer(p_rfi in xxfnd_rfis%rowtype, p_response_text in clob, p_by in varchar2) is
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
        -- providers from the Approval Setup answer in turn: the next one, else the review
        if p_rfi.approval_type_code is not null
           and xxfnd_approval_rule_pkg.next_step(p_rfi.approval_type_code, to_char(p_rfi.rfi_id)) = 'Y' then
            update xxfnd_rfis set rfi_status = 'WAITING_FOR_INFORMATION' where rfi_id = p_rfi.rfi_id;
            open_response(p_rfi.rfi_id);
        else
            start_review(p_rfi.rfi_id);
        end if;
    end record_answer;

    procedure respond(p_rfi_id in number, p_response_text in clob) is
        l_rfi xxfnd_rfis%rowtype;
    begin
        select * into l_rfi from xxfnd_rfis where rfi_id = p_rfi_id for update;
        if l_rfi.recipient_type <> 'USER'
           or instr(',' || recipient(p_rfi_id) || ',', ',' || upper(xxfnd_util_pkg.current_user) || ',') = 0 then
            raise_application_error(-20502, 'This request for information is not addressed to you.');
        end if;
        if l_rfi.rfi_status not in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING', 'RESPONDED') then
            raise_application_error(-20503, 'This request for information is closed.');
        end if;
        xxfnd_task_pkg.complete_open('RFI_RESPONSE', to_char(p_rfi_id));
        record_answer(l_rfi, p_response_text, xxfnd_util_pkg.current_user);
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
        xxfnd_vpd_pkg.end_trusted;
        return l_rfi.rfi_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end respond_by_token;

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
        select * into l_rfi from xxfnd_rfis where rfi_id = p_rfi_id for update;
        if l_rfi.rfi_status in ('RESOLVED', 'REJECTED_RETURNED', 'CANCELLED') then
            raise_application_error(-20503, 'This request for information is closed.');
        end if;
        close_round(p_rfi_id, l_rfi.round_no, 'ASKED_AGAIN', p_question);
        xxfnd_task_pkg.complete_open('RFI_REVIEW', to_char(p_rfi_id));
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
        if l_rfi.recipient_type = 'USER' then
            open_response(p_rfi_id);
        else
            l_token := new_token(p_rfi_id, l_rfi.due_date);
        end if;
        return l_token;
    end ask_again;

    procedure resolve(p_rfi_id in number, p_status in varchar2, p_notes in varchar2) is
        l_rfi xxfnd_rfis%rowtype;
    begin
        if p_status not in ('RESOLVED', 'REJECTED_RETURNED', 'CANCELLED', 'ON_HOLD_INVESTIGATION') then
            raise_application_error(-20506, 'Status ' || p_status || ' cannot be set here.');
        end if;
        begin
            select * into l_rfi from xxfnd_rfis where rfi_id = p_rfi_id for update;
        exception
            when no_data_found then
                raise_application_error(-20507, 'Request for information ' || p_rfi_id || ' does not exist.');
        end;
        update xxfnd_rfis
           set rfi_status = p_status, resolution_notes = p_notes,
               resolved_date = case when p_status <> 'ON_HOLD_INVESTIGATION' then systimestamp end,
               response_token_hash = case when p_status <> 'ON_HOLD_INVESTIGATION' then null else response_token_hash end
         where rfi_id = p_rfi_id;
        if p_status <> 'ON_HOLD_INVESTIGATION' then
            close_round(p_rfi_id, l_rfi.round_no, p_status, p_notes);
        end if;
        if p_status in ('RESOLVED', 'REJECTED_RETURNED') then
            xxfnd_task_pkg.complete_open('RFI_REVIEW', to_char(p_rfi_id));
        elsif p_status = 'CANCELLED' then
            xxfnd_task_pkg.cancel_open('RFI_RESPONSE', to_char(p_rfi_id));
            xxfnd_task_pkg.cancel_open('RFI_REVIEW', to_char(p_rfi_id));
        end if;
    end resolve;

    procedure send_email(p_rfi_id in number, p_response_url in varchar2 default null) is
        l_rfi      xxfnd_rfis%rowtype;
        l_to       varchar2(320);
        l_name     varchar2(360);
        l_template varchar2(50);
        l_subject  varchar2(500);
        l_body     clob;
        l_json     json_object_t := json_object_t();
        l_tokens   clob;
        l_mail_id  number;
    begin
        select * into l_rfi from xxfnd_rfis where rfi_id = p_rfi_id;
        if xxfnd_workflow_switch_pkg.email_enabled(null, l_rfi.application_code) = 'N' then
            return;
        end if;
        if l_rfi.recipient_type = 'USER' then
            select max(email_address), max(full_name) into l_to, l_name
              from xxfnd_employees where user_name = upper(l_rfi.recipient_user_name);
            l_template := 'RFI_RAISED_INTERNAL';
        else
            l_to := l_rfi.recipient_email;
            l_name := l_rfi.recipient_name;
            l_template := 'RFI_RAISED_EXTERNAL';
        end if;
        if l_to is null then
            return;
        end if;
        select nvl(t.subject, n.subject), nvl(t.body_html, n.body_html)
          into l_subject, l_body
          from xxfnd_notification_templates n
          left join xxfnd_notification_templates_tl t
            on t.template_code = n.template_code and t.language_code = xxfnd_util_pkg.current_lang
         where n.template_code = l_template;
        l_json.put('RFI_NUMBER',   l_rfi.rfi_number);
        l_json.put('DESCRIPTION',  apex_escape.html(l_rfi.description));
        l_json.put('DUE_DATE',     to_char(l_rfi.due_date, 'DD-Mon-YYYY'));
        l_json.put('CONTACT_NAME', apex_escape.html(nvl(l_name, 'Sir/Madam')));
        l_json.put('RESPONSE_URL', p_response_url);
        l_tokens := l_json.to_clob;
        l_mail_id := apex_mail.send(
                         p_to        => l_to,
                         p_from      => apex_app_setting.get_value('MAIL_FROM'),
                         p_subj      => dbms_lob.substr(xxfnd_util_pkg.replace_tokens(l_subject, l_tokens), 500, 1),
                         p_body      => to_clob(l_rfi.description),
                         p_body_html => xxfnd_util_pkg.replace_tokens(l_body, l_tokens));
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

end xxfnd_rfi_pkg;
/

-- messages of the RFI workflow (administrators may change the texts; existing rows are kept)
merge into xxfnd_messages d
using (select 'XXFND_RFI_QUESTION_REQUIRED' code, 'Enter the new question in Notes / New Question before asking again.' txt, -20508 num from dual) s
   on (d.message_code = s.code and d.language_code = 'en')
 when not matched then insert (message_code, language_code, message_text, error_number) values (s.code, 'en', s.txt, s.num);
commit;
