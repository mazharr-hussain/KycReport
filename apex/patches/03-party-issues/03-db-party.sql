-- Patch 03 - party issues: database changes (run as the parsing schema).
-- 16d (new columns, contact type PERSON, main contact details from older contact rows), 16 (RFI to a contact person),
-- 16b (case lock allows a party merge; new party from a request gets a contact person), 16e (XXCMP_PARTY_PKG).
-- All idempotent. Works in SQL Workshop > SQL Scripts and in SQLcl.

-- ==== 16d-parties.sql
--------------------------------------------------------------------------------
-- 16d Parties (party feature: pages 20-23)
--   Party-level contact details (email, phone, website, fax) on XXCMP_PARTIES.
--   Contact persons on XXCMP_PARTY_CONTACTS (name, job title, email, phone).
--   (XXCMP_PARTY_PKG is in 16e: it uses the request and case tables created in 16b.)
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'EMAIL',                'varchar2(320)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'PHONE',                'varchar2(50)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'WEBSITE',              'varchar2(500)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'FAX',                  'varchar2(50)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'MERGED_INTO_PARTY_ID', 'number');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'MERGE_NOTE',           'varchar2(1000)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_CONTACTS', 'JOB_TITLE',            'varchar2(240)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_CONTACTS', 'EMAIL',                'varchar2(320)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_CONTACTS', 'PHONE',                'varchar2(50)');
end;
/
comment on column xxcmp_parties.email is 'Main email of the party (contact persons are in XXCMP_PARTY_CONTACTS).';
comment on column xxcmp_parties.merged_into_party_id is 'Set when Compliance merged this duplicate into another party; the party is then disabled.';
comment on column xxcmp_party_contacts.contact_type is 'PERSON for a contact person (name, job title, email, phone); EMAIL/PHONE/... rows are from before release 18.';

-- contact type for contact persons
merge into xxfnd_lookup_values t
using (select 'CONTACT_TYPE' lookup_type, 'PERSON' lookup_code from dual) s
   on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
 when not matched then insert (lookup_type, lookup_code, meaning, display_sequence)
                       values ('CONTACT_TYPE', 'PERSON', 'Contact Person', 5);

-- one-off: the main email / phone / website of a party from its older contact rows (only where still empty)
update xxcmp_parties p
   set email = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                  from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'EMAIL' and c.enabled_flag = 'Y')
 where p.email is null
   and exists (select 1 from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'EMAIL' and c.enabled_flag = 'Y');
update xxcmp_parties p
   set phone = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                  from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type in ('PHONE', 'MOBILE') and c.enabled_flag = 'Y')
 where p.phone is null
   and exists (select 1 from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type in ('PHONE', 'MOBILE') and c.enabled_flag = 'Y');
update xxcmp_parties p
   set website = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                    from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'WEBSITE' and c.enabled_flag = 'Y')
 where p.website is null
   and exists (select 1 from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'WEBSITE' and c.enabled_flag = 'Y');
commit;

-- ==== 16-kyc-rules.sql
--------------------------------------------------------------------------------
-- 09_xxcmp_rules.sql
-- Business rules that sit on the tables:
--   * maker-checker triggers on the three controlled configuration tables
--   * party / RFI numbering
--   * ownership-cycle check on party relationships
--   * XXCMP_KYC_PKG: mandatory-document resolution, party match check, RFI
-- Depends on 03 (approval, security), 07 (attachments), 08 (workflow).
-- Needs: grant execute on dbms_crypto to <parsing schema>  (RFI tokens).
--------------------------------------------------------------------------------

--==============================================================================
-- Maker-checker (XXFND_APPROVAL_PKG.APPLY_RULES)
--==============================================================================
create or replace trigger xxcmp_answer_options_mc
    before insert or update on xxcmp_answer_options
    for each row
begin
    xxfnd_approval_pkg.apply_rules(inserting, :old.approval_status, :new.approval_status,
                                   :old.last_updated_by, :new.approved_by, :new.approved_date);
end;
/

create or replace trigger xxcmp_attachment_rules_mc
    before insert or update on xxcmp_attachment_rules
    for each row
begin
    xxfnd_approval_pkg.apply_rules(inserting, :old.approval_status, :new.approval_status,
                                   :old.last_updated_by, :new.approved_by, :new.approved_date);
end;
/

create or replace trigger xxfnd_int_purposes_mc
    before insert or update on xxfnd_integration_purposes
    for each row
begin
    xxfnd_approval_pkg.apply_rules(inserting, :old.approval_status, :new.approval_status,
                                   :old.last_updated_by, :new.approved_by, :new.approved_date);
end;
/

-- An approved scoring change raises the questionnaire version, so responses
-- record which version they were scored against.
create or replace trigger xxcmp_answer_options_ver
    after update of approval_status on xxcmp_answer_options
    for each row
    when (new.approval_status = 'APPROVED' and old.approval_status <> 'APPROVED')
begin
    update xxcmp_questionnaires q
       set q.current_version_number = q.current_version_number + 1
     where q.questionnaire_code = (select questionnaire_code from xxcmp_questions where question_id = :new.question_id);
end;
/

--==============================================================================
-- Numbering
--==============================================================================
create or replace trigger xxcmp_parties_num
    before insert on xxcmp_parties
    for each row
    when (new.party_number is null)
begin
    :new.party_number := 'P-' || lpad(xxcmp_party_number_s.nextval, 6, '0');
end;
/

-- RFIs are looked up by recipient (requesters' data security, their document downloads, the home page).
create index if not exists xxcmp_rfis_n2 on xxcmp_rfis (upper(recipient_user_name));

create or replace trigger xxcmp_rfis_num
    before insert on xxcmp_rfis
    for each row
    when (new.rfi_number is null)
begin
    :new.rfi_number := 'RFI-' || lpad(xxcmp_rfi_number_s.nextval, 6, '0');
end;
/

--==============================================================================
-- Ownership cycles (A owns B owns C owns A) are rejected. Checked after the
-- statement because the check reads the table being changed.
--==============================================================================
create or replace trigger xxcmp_party_rel_cycle
    for insert or update of subject_party_id, object_party_id, end_date on xxcmp_party_relationships
    compound trigger

    type t_pair is record (subject_id number, object_id number);
    type t_pairs is table of t_pair index by pls_integer;
    g_pairs t_pairs;

    after each row is
        l_pair t_pair;
    begin
        l_pair.subject_id := :new.subject_party_id;
        l_pair.object_id  := :new.object_party_id;
        g_pairs(g_pairs.count + 1) := l_pair;
    end after each row;

    after statement is
        l_count pls_integer;
    begin
        for i in 1 .. g_pairs.count loop
            select count(*) into l_count
              from (select r.object_party_id
                      from xxcmp_party_relationships r
                     where r.end_date is null or r.end_date >= trunc(sysdate)
                     start with r.subject_party_id = g_pairs(i).object_id
                   connect by nocycle prior r.object_party_id = r.subject_party_id
                          and (r.end_date is null or r.end_date >= trunc(sysdate)))
             where object_party_id = g_pairs(i).subject_id;
            if l_count > 0 then
                g_pairs.delete;
                raise_application_error(-20500, 'This relationship would create an ownership loop.');
            end if;
        end loop;
        g_pairs.delete;
    end after statement;
end xxcmp_party_rel_cycle;
/

--==============================================================================
-- XXCMP_KYC_PKG
--==============================================================================
create or replace package xxcmp_kyc_pkg authid definer as

    -- Document categories required for a record, from approved rules; the most
    -- specific rule per category wins (jurisdiction + entity type, then either,
    -- then the general rule), PRIORITY breaks ties.
    function mandatory_categories(p_entity_name  in varchar2,
                                  p_jurisdiction in varchar2,
                                  p_entity_type  in varchar2) return apex_t_varchar2;

    -- Mandatory categories with no current, unexpired attachment on the record.
    function missing_categories(p_entity_name  in varchar2,
                                p_pk1_value    in varchar2,
                                p_jurisdiction in varchar2,
                                p_entity_type  in varchar2) return apex_t_varchar2;

    -- Existing party that is certainly the same one (registration number +
    -- jurisdiction for organisations; name + date of birth for persons), or null.
    function exact_party_match(p_party_type          in varchar2,
                               p_party_name          in varchar2,
                               p_registration_number in varchar2 default null,
                               p_jurisdiction        in varchar2 default null,
                               p_date_of_birth       in date     default null) return number;

    -- 0-100 similarity of two names after normalisation (case, punctuation,
    -- common legal suffixes). Used by the Possible Matches region.
    function name_similarity(p_name_1 in varchar2, p_name_2 in varchar2) return number deterministic;

    -- Raise an RFI. For an external party a one-time token is generated; its
    -- hash is stored and the token itself is returned for the email link only.
    procedure create_rfi(p_entity_name         in varchar2,
                         p_pk1_value           in varchar2,
                         p_recipient_type      in varchar2,
                         p_rfi_category        in varchar2,
                         p_description         in varchar2,
                         p_continue_other_work in varchar2,
                         p_due_date            in date,
                         p_recipient_user_name in varchar2 default null,
                         p_party_contact_id    in number   default null,
                         p_rfi_id              out number,
                         p_token               out varchar2);

    -- Participant of the RFI_RESPONSE task: the internal recipient.
    function rfi_recipient(p_rfi_id in number) return varchar2;

    -- Response from the requesting department (signed-in user).
    procedure respond(p_rfi_id in number, p_response_text in clob);
    -- Response from an external party through the public response page.
    function respond_by_token(p_token in varchar2, p_response_text in clob) return number;
    -- Officer closes the RFI.
    procedure resolve(p_rfi_id in number, p_status in varchar2, p_notes in varchar2);

    -- Emails the recipient using template RFI_RAISED_INTERNAL or RFI_RAISED_EXTERNAL
    -- (APEX_MAIL queue). P_RESPONSE_URL is the public response page link with the token.
    procedure send_rfi_email(p_rfi_id in number, p_response_url in varchar2 default null);

end xxcmp_kyc_pkg;
/

create or replace package body xxcmp_kyc_pkg as

    function mandatory_categories(p_entity_name  in varchar2,
                                  p_jurisdiction in varchar2,
                                  p_entity_type  in varchar2) return apex_t_varchar2 is
        l_result apex_t_varchar2;
    begin
        select category_code bulk collect into l_result
          from (select r.category_code, r.mandatory_flag,
                       row_number() over (partition by r.category_code
                                          order by case when r.jurisdiction is not null then 0 else 1 end
                                                 + case when r.entity_type  is not null then 0 else 1 end,
                                                   case when r.jurisdiction is not null then 0 else 1 end,
                                                   r.priority) rn
                  from xxcmp_attachment_rules r
                 where r.entity_name = p_entity_name
                   and r.enabled_flag = 'Y'
                   and r.approval_status = 'APPROVED'
                   and (r.jurisdiction is null or r.jurisdiction = p_jurisdiction)
                   and (r.entity_type  is null or r.entity_type  = p_entity_type))
         where rn = 1 and mandatory_flag = 'Y'
         order by category_code;
        return l_result;
    end mandatory_categories;

    function missing_categories(p_entity_name  in varchar2,
                                p_pk1_value    in varchar2,
                                p_jurisdiction in varchar2,
                                p_entity_type  in varchar2) return apex_t_varchar2 is
        l_required apex_t_varchar2 := mandatory_categories(p_entity_name, p_jurisdiction, p_entity_type);
        l_missing  apex_t_varchar2 := apex_t_varchar2();
        l_count    pls_integer;
    begin
        for i in 1 .. l_required.count loop
            select count(*) into l_count
              from xxfnd_attached_documents_v v
             where v.entity_name = p_entity_name
               and v.pk1_value   = p_pk1_value
               and v.category_code = l_required(i)
               and v.expired_flag = 'N'
               and (v.upload_status in ('STORED','NOT_APPLICABLE'));
            if l_count = 0 then
                l_missing.extend;
                l_missing(l_missing.count) := l_required(i);
            end if;
        end loop;
        return l_missing;
    end missing_categories;

    function normalise(p_name in varchar2) return varchar2 is
        l_name varchar2(4000) := ' ' || upper(p_name) || ' ';
    begin
        l_name := regexp_replace(l_name, '[^A-Z0-9 ]', ' ');
        l_name := regexp_replace(l_name, ' (LTD|LIMITED|LLC|INC|INCORPORATED|CORP|CORPORATION|CO|COMPANY|PLC|SA|AG|GMBH|WLL|FZE|FZCO|FZ LLC|BV|NV) ', ' ');
        return trim(regexp_replace(l_name, ' +', ' '));
    end normalise;

    function name_similarity(p_name_1 in varchar2, p_name_2 in varchar2) return number deterministic is
    begin
        if p_name_1 is null or p_name_2 is null then
            return 0;
        end if;
        return utl_match.jaro_winkler_similarity(normalise(p_name_1), normalise(p_name_2));
    end name_similarity;

    function exact_party_match(p_party_type          in varchar2,
                               p_party_name          in varchar2,
                               p_registration_number in varchar2 default null,
                               p_jurisdiction        in varchar2 default null,
                               p_date_of_birth       in date     default null) return number is
        l_id number;
    begin
        if p_party_type = 'ORGANIZATION' and p_registration_number is not null then
            select min(party_id) into l_id
              from xxcmp_parties
             where party_type = 'ORGANIZATION'
               and upper(replace(registration_number, ' ')) = upper(replace(p_registration_number, ' '))
               and nvl(jurisdiction, '#') = nvl(p_jurisdiction, '#')
               and enabled_flag = 'Y';
        elsif p_party_type = 'PERSON' and p_date_of_birth is not null then
            select min(party_id) into l_id
              from xxcmp_parties
             where party_type = 'PERSON'
               and date_of_birth = p_date_of_birth
               and upper(party_name) = upper(p_party_name)
               and enabled_flag = 'Y';
        end if;
        return l_id;
    end exact_party_match;

    function hash_token(p_token in varchar2) return varchar2 is
    begin
        return rawtohex(dbms_crypto.hash(utl_i18n.string_to_raw(p_token, 'AL32UTF8'), dbms_crypto.hash_sh256));
    end hash_token;

    procedure create_rfi(p_entity_name         in varchar2,
                         p_pk1_value           in varchar2,
                         p_recipient_type      in varchar2,
                         p_rfi_category        in varchar2,
                         p_description         in varchar2,
                         p_continue_other_work in varchar2,
                         p_due_date            in date,
                         p_recipient_user_name in varchar2 default null,
                         p_party_contact_id    in number   default null,
                         p_rfi_id              out number,
                         p_token               out varchar2) is
        l_hash    varchar2(128);
        l_task_id number;
    begin
        xxfnd_util_pkg.assert_lookup('RFI_CATEGORY', p_rfi_category, 'RFI category');
        if p_due_date is not null and p_due_date < trunc(sysdate) then
            raise_application_error(-20501, 'The due date cannot be in the past.');
        end if;
        if p_recipient_type = 'EXTERNAL_PARTY' then
            p_token := lower(rawtohex(dbms_crypto.randombytes(32)));
            l_hash  := hash_token(p_token);
        end if;
        insert into xxcmp_rfis (entity_name, pk1_value, recipient_type, recipient_user_name,
                                recipient_party_contact_id, rfi_category, description, continue_other_work_flag,
                                rfi_status, due_date, response_token_hash, token_expiry_date)
        values (p_entity_name, p_pk1_value, p_recipient_type, upper(p_recipient_user_name),
                p_party_contact_id, p_rfi_category, p_description, p_continue_other_work,
                case when p_continue_other_work = 'Y' then 'WAITING_FOR_INFORMATION' else 'ON_HOLD_PENDING' end,
                p_due_date, l_hash,
                case when l_hash is not null
                     then cast(nvl(p_due_date, trunc(sysdate) + 14) + 1 as timestamp) end)
        returning rfi_id into p_rfi_id;
        -- An internal recipient answers through an APEX action task in My Tasks; an external
        -- party answers through the emailed link (no task: it has no application account).
        if p_recipient_type = 'REQUESTING_DEPARTMENT' then
            l_task_id := xxfnd_task_pkg.create_task('RFI_RESPONSE', to_char(p_rfi_id));
            update xxcmp_rfis set response_task_id = l_task_id where rfi_id = p_rfi_id;
        end if;
    end create_rfi;

    function rfi_recipient(p_rfi_id in number) return varchar2 is
        l_user xxcmp_rfis.recipient_user_name%type;
    begin
        select recipient_user_name into l_user from xxcmp_rfis where rfi_id = p_rfi_id;
        return l_user;
    end rfi_recipient;

    -- A response has arrived: the Compliance team reviews it (RFI_REVIEW action task).
    procedure start_review(p_rfi_id in number) is
        l_task_id number;
    begin
        l_task_id := xxfnd_task_pkg.create_task('RFI_REVIEW', to_char(p_rfi_id));
        update xxcmp_rfis set review_task_id = l_task_id where rfi_id = p_rfi_id;
    end start_review;

    procedure respond(p_rfi_id in number, p_response_text in clob) is
        l_rfi xxcmp_rfis%rowtype;
    begin
        select * into l_rfi from xxcmp_rfis where rfi_id = p_rfi_id for update;
        if l_rfi.recipient_type <> 'REQUESTING_DEPARTMENT'
           or upper(l_rfi.recipient_user_name) <> upper(xxfnd_util_pkg.current_user) then
            raise_application_error(-20502, 'This request for information is not addressed to you.');
        end if;
        if l_rfi.rfi_status not in ('WAITING_FOR_INFORMATION','ON_HOLD_PENDING') then
            raise_application_error(-20503, 'This request for information is closed.');
        end if;
        update xxcmp_rfis set response_text = p_response_text, responded_date = systimestamp
         where rfi_id = p_rfi_id;
        xxfnd_task_pkg.complete_open('RFI_RESPONSE', to_char(p_rfi_id));
        xxfnd_task_pkg.cancel_open('RFI_REVIEW', to_char(p_rfi_id));   -- a newer answer replaces the older one
        start_review(p_rfi_id);
    end respond;

    function respond_by_token(p_token in varchar2, p_response_text in clob) return number is
        l_rfi  xxcmp_rfis%rowtype;
        l_hash varchar2(128) := hash_token(p_token);   -- private function: not callable from SQL
    begin
        -- The caller is an anonymous party (APP_USER nobody); the token is the authorisation,
        -- so row-level data security is bypassed for this call only.
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select * into l_rfi from xxcmp_rfis
             where response_token_hash = l_hash
               for update;
        exception
            when no_data_found then
                raise_application_error(-20504, 'This link is not valid.');
        end;
        if l_rfi.token_expiry_date < systimestamp
           or l_rfi.rfi_status not in ('WAITING_FOR_INFORMATION','ON_HOLD_PENDING') then
            raise_application_error(-20505, 'This link has expired or the request is closed.');
        end if;
        -- One-time: the hash is cleared once the party has answered.
        update xxcmp_rfis
           set response_text = p_response_text, responded_date = systimestamp,
               response_token_hash = null, token_expiry_date = null
         where rfi_id = l_rfi.rfi_id;
        start_review(l_rfi.rfi_id);
        xxfnd_vpd_pkg.end_trusted;
        return l_rfi.rfi_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end respond_by_token;

    procedure resolve(p_rfi_id in number, p_status in varchar2, p_notes in varchar2) is
    begin
        if p_status not in ('RESOLVED','REJECTED_RETURNED','CANCELLED','ON_HOLD_INVESTIGATION') then
            raise_application_error(-20506, 'Status ' || p_status || ' cannot be set here.');
        end if;
        update xxcmp_rfis
           set rfi_status = p_status,
               resolution_notes = p_notes,
               resolved_date = case when p_status in ('RESOLVED','REJECTED_RETURNED','CANCELLED') then systimestamp end,
               response_token_hash = case when p_status in ('RESOLVED','REJECTED_RETURNED','CANCELLED') then null
                                          else response_token_hash end
         where rfi_id = p_rfi_id;
        if sql%rowcount = 0 then
            raise_application_error(-20507, 'Request for information ' || p_rfi_id || ' does not exist.');
        end if;
        if p_status in ('RESOLVED','REJECTED_RETURNED') then
            xxfnd_task_pkg.complete_open('RFI_REVIEW', to_char(p_rfi_id));
        elsif p_status = 'CANCELLED' then
            xxfnd_task_pkg.cancel_open('RFI_RESPONSE', to_char(p_rfi_id));
            xxfnd_task_pkg.cancel_open('RFI_REVIEW', to_char(p_rfi_id));
        end if;
    end resolve;

    procedure send_rfi_email(p_rfi_id in number, p_response_url in varchar2 default null) is
        l_rfi      xxcmp_rfis%rowtype;
        l_to       varchar2(320);
        l_name     varchar2(240);
        l_template varchar2(50);
        l_subject  varchar2(500);
        l_body     clob;
        l_tokens   clob;
        l_json     json_object_t;
        l_mail_id  number;
    begin
        select * into l_rfi from xxcmp_rfis where rfi_id = p_rfi_id;
        if l_rfi.recipient_type = 'REQUESTING_DEPARTMENT' then
            select email_address, full_name into l_to, l_name
              from xxfnd_employees where user_name = upper(l_rfi.recipient_user_name);
            l_template := 'RFI_RAISED_INTERNAL';
        else
            select coalesce(email, case when contact_type = 'EMAIL' then contact_value end), contact_name into l_to, l_name
              from xxcmp_party_contacts where party_contact_id = l_rfi.recipient_party_contact_id;
            l_template := 'RFI_RAISED_EXTERNAL';
        end if;

        select nvl(t.subject, n.subject), nvl(t.body_html, n.body_html)
          into l_subject, l_body
          from xxfnd_notification_templates n
          left join xxfnd_notification_templates_tl t
            on t.template_code = n.template_code and t.language_code = xxfnd_util_pkg.current_lang
         where n.template_code = l_template;

        l_json := json_object_t();
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
    end send_rfi_email;

end xxcmp_kyc_pkg;
/

-- ==== 16b-kyc-requests-cases.sql
--------------------------------------------------------------------------------
-- 16b KYC requests and cases  (release R13)
-- Module 1 (intake) and Module 2 (investigation, decision) data and logic.
--   XXCMP_REQUESTS            a KYC request (new onboarding, periodic or event-triggered review)
--   XXCMP_REQUEST_ANSWERS     questionnaire answers (requester at intake, officer in the case)
--   XXCMP_CASES               the compliance case opened from a request
--   XXCMP_CASE_DECISIONS      approval history per level
--   XXCMP_SCREENINGS          registry / sanctions / PEP / adverse-media checks
--   XXCMP_DOC_VERIFICATIONS   genuine-and-current check per attached document
--   XXCMP_UBO_DETERMINATIONS  the officer's beneficial-owner decisions
--   XXCMP_CASE_NOTES          investigation notes
--   XXCMP_REQUEST_PKG / XXCMP_CASE_PKG  logic behind the screens and the KYC_REQUEST /
--                             KYC_CASE APEX workflows
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create sequence if not exists xxcmp_request_number_s start with 1 nocache;
create sequence if not exists xxcmp_case_number_s start with 1 nocache;

create table if not exists xxcmp_requests (
    request_id             number generated by default on null as identity,
    request_number         varchar2(30)   not null,
    request_type           varchar2(30)   default 'NEW_ONBOARDING' not null,
    trigger_source         varchar2(30)   default 'MANUAL' not null,
    parent_request_id      number,
    parent_case_id         number,
    party_id               number,
    party_type             varchar2(30)   not null,
    party_name             varchar2(360)  not null,
    registration_number    varchar2(100),
    jurisdiction           varchar2(30),
    entity_type            varchar2(30),
    date_of_birth          date,
    nationality            varchar2(30),
    requesting_department  varchar2(240),
    requester_user_name    varchar2(255)  not null,
    questionnaire_code     varchar2(30),
    intake_score           number,
    intake_critical_flag   varchar2(1),
    intake_outcome         varchar2(30),
    request_status         varchar2(30)   default 'DRAFT' not null,
    justification          varchar2(4000),
    submitted_date         timestamp,
    completed_date         timestamp,
    workflow_id            number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_requests_pk primary key (request_id),
    constraint xxcmp_requests_uk1 unique (request_number),
    constraint xxcmp_requests_fk1 foreign key (party_id) references xxcmp_parties (party_id),
    constraint xxcmp_requests_fk2 foreign key (parent_request_id) references xxcmp_requests (request_id),
    constraint xxcmp_requests_fk3 foreign key (questionnaire_code) references xxcmp_questionnaires (questionnaire_code),
    constraint xxcmp_requests_ck1 check (request_type in ('NEW_ONBOARDING','PERIODIC_REVIEW','EVENT_TRIGGERED_REVIEW')),
    constraint xxcmp_requests_ck2 check (trigger_source in ('MANUAL','SCHEDULED','EVENT_DRIVEN')),
    constraint xxcmp_requests_ck3 check (request_status in ('DRAFT','SUBMITTED','IN_PROGRESS','COMPLETED','REJECTED','CANCELLED')),
    constraint xxcmp_requests_ck4 check (intake_outcome in ('NOT_REQUIRED','AUTO_APPROVED','ASSIGNED')),
    constraint xxcmp_requests_ck5 check (party_type in ('ORGANIZATION','PERSON')),
    constraint xxcmp_requests_ck6 check (intake_critical_flag in ('Y','N'))
);
create index if not exists xxcmp_requests_n1 on xxcmp_requests (requester_user_name, request_status);

-- Counterparty selection and matching (existing party chosen by the requester, or a new one that Compliance
-- links to an existing party or confirms as new). Individuals are matched on their identity document.
begin
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'PARTY_SELECTION',     q'[varchar2(10) default 'NEW']');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'INCORPORATION_DATE',  'date');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'ID_TYPE',             'varchar2(30)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'ID_NUMBER',           'varchar2(100)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_ACK_FLAG',      q'[varchar2(1) default 'N']');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_STATUS',        'varchar2(20)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_RESOLVED_BY',   'varchar2(255)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_RESOLVED_DATE', 'timestamp');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_NOTE',          'varchar2(1000)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CONTACT_NAME',        'varchar2(240)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CONTACT_EMAIL',       'varchar2(320)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CONTACT_PHONE',       'varchar2(50)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',  'ID_TYPE',             'varchar2(30)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',  'ID_NUMBER',           'varchar2(100)');
end;
/
comment on column xxcmp_requests.party_selection is 'EXISTING: the requester chose a party from the party list; NEW: a counterparty not yet known.';
comment on column xxcmp_requests.match_ack_flag is 'Y: the requester saw possible existing parties and declared none of them is the counterparty.';
comment on column xxcmp_requests.match_status is 'SELECTED (existing party chosen), NEW (no possible match: new party created), PENDING (possible matches: Compliance decides), MERGED (Compliance linked it to an existing party), CONFIRMED_NEW (Compliance confirmed a new party).';
comment on column xxcmp_parties.id_type is 'Individuals: identity document type (lookup ID_DOCUMENT_TYPE).';
comment on column xxcmp_parties.id_number is 'Individuals: identity document number, used for duplicate checks.';
create index if not exists xxcmp_parties_n3 on xxcmp_parties (upper(replace(id_number, ' ')));
create index if not exists xxcmp_parties_n4 on xxcmp_parties (upper(replace(registration_number, ' ')));
create index if not exists xxcmp_requests_n2 on xxcmp_requests (party_id);
comment on table xxcmp_requests is 'KYC request from a requesting department, or a periodic / event-triggered review. Counterparty details are captured on the request; on evaluation the request is linked to an existing party or a new one.';

create table if not exists xxcmp_cases (
    case_id                number generated by default on null as identity,
    case_number            varchar2(30)   not null,
    request_id             number         not null,
    party_id               number         not null,
    parent_case_id         number,
    case_status            varchar2(30)   default 'INVESTIGATION' not null,
    assigned_to            varchar2(255),
    risk_tier              varchar2(30),
    enhanced_kyc_flag      varchar2(1)    default 'N' not null,
    pep_flag               varchar2(1)    default 'N' not null,
    sla_due_date           date,
    investigation_completed_date timestamp,
    current_level          number,
    decision               varchar2(30),
    decision_date          timestamp,
    conditions             varchar2(4000),
    next_review_date       date,
    next_review_reason     varchar2(1000),
    sar_required_flag      varchar2(1),
    sar_notes              varchar2(4000),
    closed_date            timestamp,
    workflow_id            number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_cases_pk primary key (case_id),
    constraint xxcmp_cases_uk1 unique (case_number),
    constraint xxcmp_cases_fk1 foreign key (request_id) references xxcmp_requests (request_id),
    constraint xxcmp_cases_fk2 foreign key (party_id) references xxcmp_parties (party_id),
    constraint xxcmp_cases_fk3 foreign key (parent_case_id) references xxcmp_cases (case_id),
    constraint xxcmp_cases_ck1 check (case_status in ('INVESTIGATION','PENDING_APPROVAL','APPROVED','REJECTED','CANCELLED')),
    constraint xxcmp_cases_ck2 check (enhanced_kyc_flag in ('Y','N')),
    constraint xxcmp_cases_ck3 check (pep_flag in ('Y','N')),
    constraint xxcmp_cases_ck4 check (decision in ('APPROVED','REJECTED')),
    constraint xxcmp_cases_ck5 check (sar_required_flag in ('Y','N'))
);
create index if not exists xxcmp_cases_n1 on xxcmp_cases (case_status, assigned_to);
create index if not exists xxcmp_cases_n2 on xxcmp_cases (party_id);
create index if not exists xxcmp_cases_n3 on xxcmp_cases (next_review_date);
comment on table xxcmp_cases is 'Compliance case: investigation, risk classification, approval and closure. A decided case is closed (CLOSED_DATE) and locked.';

create table if not exists xxcmp_request_answers (
    answer_id              number generated by default on null as identity,
    request_id             number         not null,
    case_id                number,
    respondent_type        varchar2(30)   not null,
    question_id            number         not null,
    answer_option_id       number,
    answer_text            varchar2(4000),
    risk_points            number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_request_answers_pk primary key (answer_id),
    constraint xxcmp_request_answers_uk1 unique (request_id, respondent_type, question_id),
    constraint xxcmp_request_answers_fk1 foreign key (request_id) references xxcmp_requests (request_id) on delete cascade,
    constraint xxcmp_request_answers_fk2 foreign key (case_id) references xxcmp_cases (case_id),
    constraint xxcmp_request_answers_fk3 foreign key (question_id) references xxcmp_questions (question_id),
    constraint xxcmp_request_answers_fk4 foreign key (answer_option_id) references xxcmp_answer_options (answer_option_id),
    constraint xxcmp_request_answers_ck1 check (respondent_type in ('REQUESTER','OFFICER'))
);
comment on table xxcmp_request_answers is 'Questionnaire answers: the requester''s at intake (scored) and the officer''s in the case (findings).';

create table if not exists xxcmp_case_decisions (
    decision_id            number generated by default on null as identity,
    case_id                number         not null,
    level_no               number         not null,
    role_code              varchar2(30),
    decided_by             varchar2(255)  not null,
    outcome                varchar2(30)   not null,
    decision_date          timestamp      default systimestamp not null,
    comments               varchar2(4000),
    task_id                number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_case_decisions_pk primary key (decision_id),
    constraint xxcmp_case_decisions_fk1 foreign key (case_id) references xxcmp_cases (case_id),
    constraint xxcmp_case_decisions_ck1 check (outcome in ('APPROVED','REJECTED'))
);
comment on table xxcmp_case_decisions is 'Every approval-level decision on a case: who, under which role, when, outcome and comments.';

create table if not exists xxcmp_screenings (
    screening_id           number generated by default on null as identity,
    case_id                number         not null,
    party_id               number         not null,
    screening_type         varchar2(30)   not null,
    match_status           varchar2(30)   default 'NO_MATCH' not null,
    pep_flag               varchar2(1)    default 'N' not null,
    sanctions_flag         varchar2(1)    default 'N' not null,
    adverse_media_flag     varchar2(1)    default 'N' not null,
    capture_method         varchar2(30)   default 'MANUAL' not null,
    source_reference       varchar2(1000),
    result_notes           varchar2(4000),
    screened_date          date           default trunc(sysdate) not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_screenings_pk primary key (screening_id),
    constraint xxcmp_screenings_fk1 foreign key (case_id) references xxcmp_cases (case_id),
    constraint xxcmp_screenings_fk2 foreign key (party_id) references xxcmp_parties (party_id),
    constraint xxcmp_screenings_ck1 check (screening_type in ('REGISTRY','SANCTIONS','PEP','ADVERSE_MEDIA')),
    constraint xxcmp_screenings_ck2 check (match_status in ('NO_MATCH','POTENTIAL_MATCH','CONFIRMED_MATCH','FALSE_POSITIVE')),
    constraint xxcmp_screenings_ck3 check (pep_flag in ('Y','N') and sanctions_flag in ('Y','N') and adverse_media_flag in ('Y','N')),
    constraint xxcmp_screenings_ck4 check (capture_method in ('MANUAL','API'))
);
comment on table xxcmp_screenings is 'One screening event per check, with all its flags. A confirmed match or a PEP flag forces the case into Enhanced KYC.';

create table if not exists xxcmp_doc_verifications (
    verification_id        number generated by default on null as identity,
    case_id                number         not null,
    attached_document_id   number         not null,
    verification_status    varchar2(30)   not null,
    notes                  varchar2(4000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_doc_verifications_pk primary key (verification_id),
    constraint xxcmp_doc_verifications_uk1 unique (case_id, attached_document_id),
    constraint xxcmp_doc_verifications_fk1 foreign key (case_id) references xxcmp_cases (case_id),
    constraint xxcmp_doc_verifications_fk2 foreign key (attached_document_id) references xxfnd_attached_documents (attached_document_id),
    constraint xxcmp_doc_verifications_ck1 check (verification_status in ('VERIFIED','REJECTED','EXPIRED'))
);
comment on table xxcmp_doc_verifications is 'Whether each document attached to the party is genuine and current, as checked for this case.';

create table if not exists xxcmp_ubo_determinations (
    ubo_id                 number generated by default on null as identity,
    case_id                number         not null,
    owner_party_id         number         not null,
    basis                  varchar2(30)   not null,
    ownership_percentage   number,
    notes                  varchar2(4000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_ubo_determinations_pk primary key (ubo_id),
    constraint xxcmp_ubo_determinations_uk1 unique (case_id, owner_party_id),
    constraint xxcmp_ubo_determinations_fk1 foreign key (case_id) references xxcmp_cases (case_id),
    constraint xxcmp_ubo_determinations_fk2 foreign key (owner_party_id) references xxcmp_parties (party_id),
    constraint xxcmp_ubo_determinations_ck1 check (basis in ('OWNERSHIP','CONTROL','FALLBACK')),
    constraint xxcmp_ubo_determinations_ck2 check (ownership_percentage between 0 and 100)
);
comment on table xxcmp_ubo_determinations is 'The officer''s decision on who the beneficial owners are, for this case (a later review never overwrites it).';

create table if not exists xxcmp_case_notes (
    note_id                number generated by default on null as identity,
    case_id                number         not null,
    related_party_id       number,
    note_text              varchar2(4000) not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_case_notes_pk primary key (note_id),
    constraint xxcmp_case_notes_fk1 foreign key (case_id) references xxcmp_cases (case_id),
    constraint xxcmp_case_notes_fk2 foreign key (related_party_id) references xxcmp_parties (party_id)
);
comment on table xxcmp_case_notes is 'Investigation notes, optionally about one related party.';

begin
    for t in (select column_value table_name from table(apex_t_varchar2(
                 'XXCMP_REQUESTS','XXCMP_CASES','XXCMP_REQUEST_ANSWERS','XXCMP_CASE_DECISIONS','XXCMP_SCREENINGS',
                 'XXCMP_DOC_VERIFICATIONS','XXCMP_UBO_DETERMINATIONS','XXCMP_CASE_NOTES'))) loop
        xxfnd_util_pkg.create_who_trigger(t.table_name);
    end loop;
end;
/

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------
create or replace package xxcmp_request_pkg authid definer as

    -- Requester questionnaire for a party type (PERSON -> INDIVIDUAL, ORGANIZATION -> CORPORATE).
    function questionnaire_for(p_party_type in varchar2) return varchar2;

    -- New DRAFT request with one empty answer row per question of its questionnaire.
    function create_request(p_party_type            in varchar2,
                            p_party_name            in varchar2,
                            p_registration_number   in varchar2 default null,
                            p_jurisdiction          in varchar2 default null,
                            p_entity_type           in varchar2 default null,
                            p_date_of_birth         in date     default null,
                            p_nationality           in varchar2 default null,
                            p_requesting_department in varchar2 default null,
                            p_justification         in varchar2 default null,
                            p_request_type          in varchar2 default 'NEW_ONBOARDING',
                            p_trigger_source        in varchar2 default 'MANUAL',
                            p_parent_request_id     in number   default null,
                            p_parent_case_id        in number   default null,
                            p_party_id              in number   default null) return number;

    -- Requesting department of the signed-in user: the department of the employee profile (matched to the
    -- REQUESTING_DEPARTMENT lookup by code or meaning), or null.
    function default_department return varchar2;
    -- Y: the user may raise requests for any department (Compliance staff: privilege CASES.VIEW); N: only for the
    -- department of the employee profile (when the profile has one).
    function can_choose_department return varchar2;
    -- Party number of an existing party that is certainly this counterparty: same registration number (organisation)
    -- or identity document number (individual) AND same country. Such a counterparty cannot be created again.
    function exact_party_number(p_party_type in varchar2, p_registration_number in varchar2,
                                p_id_number in varchar2, p_country in varchar2) return varchar2;

    -- Counterparty rules (null = acceptable). EXISTING: a party must be chosen. NEW: name and contact details
    -- (contact name, email, phone); the other details are optional for the requester (dates not in the future).
    -- A NEW counterparty with the same registration / identity number and country as an existing party is
    -- refused, even when the requester confirmed it: use the existing party.
    -- P_DRAFT = Y checks only what a draft needs (type and name or party).
    function counterparty_error(p_party_selection     in varchar2,
                                p_party_id            in number,
                                p_party_type          in varchar2,
                                p_party_name          in varchar2,
                                p_registration_number in varchar2,
                                p_entity_type         in varchar2,
                                p_incorporation_date  in date,
                                p_id_type             in varchar2,
                                p_id_number           in varchar2,
                                p_jurisdiction        in varchar2,
                                p_date_of_birth       in date,
                                p_nationality         in varchar2,
                                p_draft               in varchar2 default 'N',
                                p_contact_name        in varchar2 default null,
                                p_contact_email       in varchar2 default null,
                                p_contact_phone       in varchar2 default null) return varchar2;

    -- Wizard step 1: creates the DRAFT request (p_request_id null) or updates it. EXISTING copies the chosen
    -- party's details; NEW keeps what was typed, clearing fields that do not apply to the type. A change of
    -- type replaces the questionnaire. P_MATCH_ACK = Y: the requester declared none of the possible matches is
    -- the counterparty (Compliance still decides at the document checklist).
    procedure save_counterparty(p_request_id            in out number,
                                p_party_selection       in varchar2,
                                p_party_id              in number,
                                p_party_type            in varchar2,
                                p_party_name            in varchar2,
                                p_registration_number   in varchar2,
                                p_entity_type           in varchar2,
                                p_incorporation_date    in date,
                                p_id_type               in varchar2,
                                p_id_number             in varchar2,
                                p_jurisdiction          in varchar2,
                                p_date_of_birth         in date,
                                p_nationality           in varchar2,
                                p_requesting_department in varchar2,
                                p_justification         in varchar2,
                                p_match_ack             in varchar2 default 'N',
                                p_draft                 in varchar2 default 'N',
                                p_contact_name          in varchar2 default null,
                                p_contact_email         in varchar2 default null,
                                p_contact_phone         in varchar2 default null);

    -- Parties a requester may choose from (requesters cannot read the party master itself): enabled parties of
    -- the type with number, name and country only. JSON array [{"party_id","party_number","party_name","country"}].
    function party_directory_json(p_party_type in varchar2) return clob;

    -- Possible existing parties for a new counterparty, strongest first (at most 10). Matching: same registration
    -- number (organisation) or identity document number (individual); name similarity; same date of incorporation
    -- or birth; same country. 100 = same registration / identity number and same country.
    -- JSON array [{"party_id","party_number","registration_number","party_name","country","score","reg_match",
    --              "reasons","exact"}]; reg_match = 0-100 similarity of the registration / identity numbers.
    function party_candidates_json(p_party_type          in varchar2,
                                   p_party_name          in varchar2,
                                   p_registration_number in varchar2,
                                   p_id_number           in varchar2,
                                   p_date                in date,
                                   p_country             in varchar2) return clob;
    function party_candidate_count(p_party_type          in varchar2,
                                   p_party_name          in varchar2,
                                   p_registration_number in varchar2,
                                   p_id_number           in varchar2,
                                   p_date                in date,
                                   p_country             in varchar2) return number;
    -- The same for a saved request (Compliance's view on the request page).
    function request_candidates_json(p_request_id in number) return clob;
    -- Y while Compliance still has to decide whether a new counterparty is an existing party.
    function match_pending(p_request_id in number) return varchar2;
    -- Compliance's decision: P_PARTY_ID = merge the counterparty into that party (the request is linked to it and the
    -- party's empty fields are completed from the request); null = confirm it as a new party.
    procedure resolve_match(p_request_id in number, p_party_id in number default null, p_note in varchar2 default null);

    -- Wizard step 2: the questionnaire as a form. Questions grouped by section (translated), each with its
    -- answer control (Yes/No and single choice: radio buttons; text, number, date: an input) and the saved answer.
    -- kyc-app.js (kycQuestionnaire.bind) copies the answers into a JSON item before submit:
    --   [{"q": question_id, "o": answer_option_id, "t": "text answer"}, ...]
    function questionnaire_html(p_request_id in number, p_respondent in varchar2 default 'REQUESTER') return clob;
    -- Required questions without an answer in P_ANSWERS (null = all answered).
    function answers_error(p_request_id in number, p_answers in clob) return varchar2;
    -- Saves the answers of a DRAFT request; only its own questions and their approved options are accepted.
    procedure save_answers(p_request_id in number, p_answers in clob);

    -- Why the request cannot be submitted yet (null = it can).
    function submit_error(p_request_id in number) return varchar2;
    -- Submits the request and starts the KYC_REQUEST workflow.
    procedure submit(p_request_id in number);

    -- Workflow steps (KYC_REQUEST). Run as system steps, not limited by data security.
    procedure evaluate(p_request_id in number);
    function outcome(p_request_id in number) return varchar2;
    procedure close_without_case(p_request_id in number);
    procedure create_case(p_request_id in number);
    procedure reject(p_request_id in number);

    -- Requester's three-stage view: Draft, Submitted, Processing, In Progress, Completed, Rejected.
    function stage(p_request_id in number) return varchar2;

    -- New review request for the party of a case (monitoring): submitted at once, always to Compliance.
    function start_review(p_case_id in number, p_request_type in varchar2, p_trigger_source in varchar2,
                          p_justification in varchar2) return number;

end xxcmp_request_pkg;
/

create or replace package xxcmp_case_pkg authid definer as

    -- Opens the case of a request and starts the KYC_CASE workflow.
    function create_case(p_request_id in number, p_assigned_to in varchar2 default null) return number;
    -- A case opened by an officer without an intake request (a request is recorded for the trail).
    function create_manual_case(p_party_id in number, p_justification in varchar2) return number;

    procedure assign(p_case_id in number, p_user_name in varchar2);

    -- Task participants.
    function investigation_owners(p_case_id in number) return varchar2;
    function level_approvers(p_case_id in number) return varchar2;

    -- Approval levels from the approval matrix (risk tier; Enhanced KYC needs two).
    function required_levels(p_case_id in number) return number;
    function level_role(p_case_id in number, p_level in number) return varchar2;
    function sar_gate(p_case_id in number) return varchar2;

    -- Y when the case is under investigation and the user may manage cases (Case page read-only otherwise).
    function is_editable(p_case_id in number) return varchar2;

    -- Investigation -> approval.
    function submit_error(p_case_id in number) return varchar2;
    procedure submit_for_approval(p_case_id in number);

    -- Approval (CASE_APPROVAL task actions and the decision page).
    function approval_error(p_case_id in number) return varchar2;
    procedure record_decision(p_case_id in number, p_outcome in varchar2, p_comments in varchar2, p_task_id in number);
    function next_review_date(p_case_id in number) return date;

    -- Workflow steps (KYC_CASE).
    procedure start_approval(p_case_id in number);
    function has_next_level(p_case_id in number) return varchar2;
    procedure approve_case(p_case_id in number);
    procedure reject_case(p_case_id in number);

    -- Screening results: a confirmed match or PEP flag forces Enhanced KYC.
    procedure apply_screening(p_case_id in number);

end xxcmp_case_pkg;
/

create or replace package body xxcmp_request_pkg as

    -- Numeric KYC parameter maintained by administrators (lookup KYC_PARAMETER, value in TAG).
    function param(p_code in varchar2, p_default in number) return number is
        l_value number;
    begin
        select max(to_number(tag default null on conversion error)) into l_value from xxfnd_lookup_values
         where lookup_type = 'KYC_PARAMETER' and lookup_code = p_code and enabled_flag = 'Y';
        return nvl(l_value, p_default);
    end param;

    function questionnaire_for(p_party_type in varchar2) return varchar2 is
    begin
        return case p_party_type when 'PERSON' then 'INDIVIDUAL' else 'CORPORATE' end;
    end questionnaire_for;

    procedure add_answer_rows(p_request_id in number, p_case_id in number, p_questionnaire in varchar2,
                              p_respondent in varchar2) is
    begin
        insert into xxcmp_request_answers (request_id, case_id, respondent_type, question_id)
        select p_request_id, p_case_id, p_respondent, q.question_id
          from xxcmp_questions q
         where q.questionnaire_code = p_questionnaire
           and q.enabled_flag = 'Y'
           and not exists (select 1 from xxcmp_request_answers a
                            where a.request_id = p_request_id and a.respondent_type = p_respondent
                              and a.question_id = q.question_id);
    end add_answer_rows;

    function create_request(p_party_type            in varchar2,
                            p_party_name            in varchar2,
                            p_registration_number   in varchar2 default null,
                            p_jurisdiction          in varchar2 default null,
                            p_entity_type           in varchar2 default null,
                            p_date_of_birth         in date     default null,
                            p_nationality           in varchar2 default null,
                            p_requesting_department in varchar2 default null,
                            p_justification         in varchar2 default null,
                            p_request_type          in varchar2 default 'NEW_ONBOARDING',
                            p_trigger_source        in varchar2 default 'MANUAL',
                            p_parent_request_id     in number   default null,
                            p_parent_case_id        in number   default null,
                            p_party_id              in number   default null) return number is
        l_id  number;
        l_qnr varchar2(30) := case when p_request_type = 'NEW_ONBOARDING' then questionnaire_for(p_party_type) end;
    begin
        insert into xxcmp_requests (request_number, request_type, trigger_source, parent_request_id, parent_case_id,
                                    party_id, party_type, party_name, registration_number, jurisdiction, entity_type,
                                    date_of_birth, nationality, requesting_department, requester_user_name,
                                    questionnaire_code, justification)
        values ('REQ-' || lpad(xxcmp_request_number_s.nextval, 6, '0'), p_request_type, p_trigger_source,
                p_parent_request_id, p_parent_case_id, p_party_id, p_party_type, p_party_name, p_registration_number,
                p_jurisdiction, p_entity_type, p_date_of_birth, p_nationality, p_requesting_department,
                xxfnd_util_pkg.current_user, l_qnr, p_justification)
        returning request_id into l_id;
        if l_qnr is not null then
            add_answer_rows(l_id, null, l_qnr, 'REQUESTER');
        end if;
        return l_id;
    end create_request;

    function norm_id(p_value in varchar2) return varchar2 is
    begin
        return upper(regexp_replace(p_value, '[^[:alnum:]]', ''));
    end norm_id;

    function default_department return varchar2 is
        l_code xxfnd_lookup_values.lookup_code%type;
    begin
        select max(v.lookup_code) keep (dense_rank first order by v.display_sequence) into l_code
          from xxfnd_employees e
          join xxfnd_lookup_values v
            on v.lookup_type = 'REQUESTING_DEPARTMENT' and v.enabled_flag = 'Y'
           and (upper(v.lookup_code) = upper(trim(e.department_name)) or upper(v.meaning) = upper(trim(e.department_name)))
         where e.user_name = upper(xxfnd_util_pkg.current_user) and e.enabled_flag = 'Y';
        return l_code;
    end default_department;

    function can_choose_department return varchar2 is
    begin
        return case when xxfnd_privilege_pkg.has_privilege('CASES', 'VIEW') then 'Y' else 'N' end;
    end can_choose_department;

    function exact_party_number(p_party_type in varchar2, p_registration_number in varchar2,
                                p_id_number in varchar2, p_country in varchar2) return varchar2 is
        l_id     varchar2(100) := norm_id(case p_party_type when 'ORGANIZATION' then p_registration_number else p_id_number end);
        l_number xxcmp_parties.party_number%type;
    begin
        if l_id is null or p_country is null then
            return null;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        select min(party_number) into l_number
          from xxcmp_parties p
         where p.party_type = p_party_type and p.enabled_flag = 'Y' and p.jurisdiction = p_country
           and upper(regexp_replace(case p.party_type when 'ORGANIZATION' then p.registration_number else p.id_number end,
                                    '[^[:alnum:]]', '')) = l_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_number;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end exact_party_number;

    function counterparty_error(p_party_selection     in varchar2,
                                p_party_id            in number,
                                p_party_type          in varchar2,
                                p_party_name          in varchar2,
                                p_registration_number in varchar2,
                                p_entity_type         in varchar2,
                                p_incorporation_date  in date,
                                p_id_type             in varchar2,
                                p_id_number           in varchar2,
                                p_jurisdiction        in varchar2,
                                p_date_of_birth       in date,
                                p_nationality         in varchar2,
                                p_draft               in varchar2 default 'N',
                                p_contact_name        in varchar2 default null,
                                p_contact_email       in varchar2 default null,
                                p_contact_phone       in varchar2 default null) return varchar2 is
        l_exact varchar2(30);
    begin
        if p_party_selection = 'EXISTING' then
            return case when p_party_id is null then 'Choose the existing counterparty.' end;
        elsif p_party_type not in ('ORGANIZATION', 'PERSON') or p_party_type is null then
            return 'Choose the counterparty type.';
        elsif trim(p_party_name) is null then
            return 'Enter the name.';
        elsif p_draft = 'Y' then
            return null;
        elsif trim(p_contact_name) is null then
            return 'Enter the contact person.';
        elsif trim(p_contact_email) is null then
            return 'Enter the contact email.';
        elsif not regexp_like(trim(p_contact_email), '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
            return 'Enter a valid contact email.';
        elsif trim(p_contact_phone) is null then
            return 'Enter the contact phone.';
        elsif p_incorporation_date > trunc(sysdate) then
            return 'The date of incorporation cannot be in the future.';
        elsif p_date_of_birth > trunc(sysdate) then
            return 'The date of birth cannot be in the future.';
        end if;
        l_exact := exact_party_number(p_party_type, p_registration_number, p_id_number, p_jurisdiction);
        if l_exact is not null then
            return 'Party ' || l_exact || ' already has this ' ||
                   case p_party_type when 'ORGANIZATION' then 'registration number' else 'identity document number' end ||
                   ' and country: use this party instead of creating a new one.';
        end if;
        return null;
    end counterparty_error;

    procedure save_counterparty(p_request_id            in out number,
                                p_party_selection       in varchar2,
                                p_party_id              in number,
                                p_party_type            in varchar2,
                                p_party_name            in varchar2,
                                p_registration_number   in varchar2,
                                p_entity_type           in varchar2,
                                p_incorporation_date    in date,
                                p_id_type               in varchar2,
                                p_id_number             in varchar2,
                                p_jurisdiction          in varchar2,
                                p_date_of_birth         in date,
                                p_nationality           in varchar2,
                                p_requesting_department in varchar2,
                                p_justification         in varchar2,
                                p_match_ack             in varchar2 default 'N',
                                p_draft                 in varchar2 default 'N',
                                p_contact_name          in varchar2 default null,
                                p_contact_email         in varchar2 default null,
                                p_contact_phone         in varchar2 default null) is
        l_error varchar2(4000) := counterparty_error(p_party_selection, p_party_id, p_party_type, p_party_name,
                                      p_registration_number, p_entity_type, p_incorporation_date, p_id_type, p_id_number,
                                      p_jurisdiction, p_date_of_birth, p_nationality, p_draft,
                                      p_contact_name, p_contact_email, p_contact_phone);
        l_new   xxcmp_requests%rowtype;
        l_old   xxcmp_requests%rowtype;
        l_party xxcmp_parties%rowtype;
        l_org   boolean;
        l_dept  xxcmp_requests.requesting_department%type := p_requesting_department;
    begin
        if l_error is not null then
            raise_application_error(-20611, l_error);
        end if;
        -- a requester raises requests for the department of the employee profile; Compliance for any department
        if can_choose_department = 'N' and default_department is not null then
            l_dept := default_department;
        end if;
        -- the values to keep: the chosen party's, or what was typed (only what applies to the type)
        if p_party_selection = 'EXISTING' then
            xxfnd_vpd_pkg.begin_trusted;    -- requesters cannot read the party master
            begin
                select * into l_party from xxcmp_parties where party_id = p_party_id and enabled_flag = 'Y';
            exception
                when no_data_found then
                    xxfnd_vpd_pkg.end_trusted;
                    raise_application_error(-20618, 'The chosen counterparty does not exist or is disabled.');
            end;
            xxfnd_vpd_pkg.end_trusted;
            l_new.party_selection := 'EXISTING';     l_new.party_id := l_party.party_id;
            l_new.party_type := l_party.party_type;  l_new.party_name := l_party.party_name;
            l_new.registration_number := l_party.registration_number; l_new.entity_type := l_party.entity_type;
            l_new.incorporation_date := l_party.incorporation_date;   l_new.id_type := l_party.id_type;
            l_new.id_number := l_party.id_number;    l_new.jurisdiction := l_party.jurisdiction;
            l_new.date_of_birth := l_party.date_of_birth;             l_new.nationality := l_party.nationality;
            l_new.match_status := 'SELECTED';        l_new.match_ack_flag := 'N';
        else
            l_org := p_party_type = 'ORGANIZATION';
            l_new.party_selection := 'NEW';          l_new.party_type := p_party_type;
            l_new.party_name := trim(p_party_name);  l_new.jurisdiction := p_jurisdiction;
            if l_org then
                l_new.registration_number := trim(p_registration_number);
                l_new.entity_type := p_entity_type;  l_new.incorporation_date := p_incorporation_date;
            else
                l_new.date_of_birth := p_date_of_birth; l_new.nationality := p_nationality;
                l_new.id_type := p_id_type;          l_new.id_number := trim(p_id_number);
            end if;
            l_new.match_ack_flag := case when p_match_ack = 'Y' then 'Y' else 'N' end;
            l_new.contact_name   := trim(p_contact_name);
            l_new.contact_email  := trim(p_contact_email);
            l_new.contact_phone  := trim(p_contact_phone);
        end if;

        if p_request_id is null then
            p_request_id := create_request(p_party_type => l_new.party_type, p_party_name => l_new.party_name,
                                           p_requesting_department => l_dept,
                                           p_justification => p_justification);
        end if;
        select * into l_old from xxcmp_requests where request_id = p_request_id for update;
        if l_old.request_status <> 'DRAFT' then
            raise_application_error(-20612, 'Request ' || l_old.request_number || ' has been submitted and can no longer be changed.');
        end if;
        update xxcmp_requests
           set party_selection       = l_new.party_selection,
               party_id              = l_new.party_id,
               party_type            = l_new.party_type,
               party_name            = l_new.party_name,
               registration_number   = l_new.registration_number,
               entity_type           = l_new.entity_type,
               incorporation_date    = l_new.incorporation_date,
               id_type               = l_new.id_type,
               id_number             = l_new.id_number,
               jurisdiction          = l_new.jurisdiction,
               date_of_birth         = l_new.date_of_birth,
               nationality           = l_new.nationality,
               match_ack_flag        = l_new.match_ack_flag,
               match_status          = l_new.match_status,
               contact_name          = l_new.contact_name,
               contact_email         = l_new.contact_email,
               contact_phone         = l_new.contact_phone,
               requesting_department = l_dept,
               justification         = p_justification,
               questionnaire_code    = questionnaire_for(l_new.party_type)
         where request_id = p_request_id;
        -- another type answers another questionnaire
        if nvl(l_old.questionnaire_code, '#') <> questionnaire_for(l_new.party_type) then
            delete from xxcmp_request_answers where request_id = p_request_id and respondent_type = 'REQUESTER';
            add_answer_rows(p_request_id, null, questionnaire_for(l_new.party_type), 'REQUESTER');
        end if;
    end save_counterparty;

    function party_directory_json(p_party_type in varchar2) return clob is
        l_json clob;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select json_arrayagg(json_object('party_id' value party_id, 'party_number' value party_number,
                                         'party_name' value party_name,
                                         'country' value xxfnd_util_pkg.lookup_meaning('JURISDICTION', jurisdiction))
                             order by party_name returning clob)
          into l_json
          from xxcmp_parties
         where party_type = p_party_type and enabled_flag = 'Y';
        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_json, '[]');
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end party_directory_json;

    function party_candidates_json(p_party_type          in varchar2,
                                   p_party_name          in varchar2,
                                   p_registration_number in varchar2,
                                   p_id_number           in varchar2,
                                   p_date                in date,
                                   p_country             in varchar2) return clob is
        l_json clob;
        l_id   varchar2(100) := norm_id(case p_party_type when 'ORGANIZATION' then p_registration_number else p_id_number end);
    begin
        if trim(p_party_name) is null and l_id is null then
            return '[]';
        end if;
        xxfnd_vpd_pkg.begin_trusted;    -- the whole party master, but only safe columns leave this function
        select json_arrayagg(json_object('party_id' value party_id, 'party_number' value party_number,
                                         'registration_number' value registration_number,
                                         'party_name' value party_name, 'country' value country,
                                         'score' value score, 'reg_match' value reg_match, 'reasons' value reasons,
                                         'exact' value case when id_hit = 'Y' and country_hit = 'Y' then 'Y' else 'N' end)
                             order by score desc, party_name returning clob)
          into l_json
          from (select m.*,
                       case when id_hit = 'Y' and country_hit = 'Y' then 100
                            when id_hit = 'Y' then 90
                            else least(89, round(similarity * 0.7 + case when date_hit = 'Y' then 20 else 0 end
                                                                + case when country_hit = 'Y' then 10 else 0 end)) end as score,
                       case when l_id is not null and party_id_number is not null
                            then round(utl_match.edit_distance_similarity(party_id_number, l_id)) end as reg_match,
                       rtrim(case when id_hit = 'Y' then case p_party_type when 'ORGANIZATION' then 'Same registration number; '
                                                                           else 'Same identity document number; ' end end
                             || case when similarity >= 70 then 'Name ' || round(similarity) || '% similar; ' end
                             || case when date_hit = 'Y' then case p_party_type when 'ORGANIZATION' then 'Same date of incorporation; '
                                                                                else 'Same date of birth; ' end end
                             || case when country_hit = 'Y' then 'Same country; ' end, '; ') as reasons
                  from (select p.party_id, p.party_number, p.party_name,
                               case p.party_type when 'ORGANIZATION' then p.registration_number else p.id_number end
                                   as registration_number,
                               upper(regexp_replace(case p.party_type when 'ORGANIZATION' then p.registration_number
                                                         else p.id_number end, '[^[:alnum:]]', '')) as party_id_number,
                               xxfnd_util_pkg.lookup_meaning('JURISDICTION', p.jurisdiction) as country,
                               case when l_id is not null
                                     -- same normalisation as NORM_ID (private functions cannot be used in SQL)
                                     and upper(regexp_replace(case p.party_type when 'ORGANIZATION' then p.registration_number
                                                                  else p.id_number end, '[^[:alnum:]]', '')) = l_id
                                    then 'Y' else 'N' end as id_hit,
                               case when trim(p_party_name) is not null
                                    then xxcmp_kyc_pkg.name_similarity(p.party_name, p_party_name) else 0 end as similarity,
                               case when p_date is not null
                                     and p_date = case p.party_type when 'ORGANIZATION' then p.incorporation_date
                                                                    else p.date_of_birth end then 'Y' else 'N' end as date_hit,
                               case when p_country is not null and p.jurisdiction = p_country then 'Y' else 'N' end as country_hit
                          from xxcmp_parties p
                         where p.party_type = p_party_type
                           and p.enabled_flag = 'Y') m
                 where id_hit = 'Y'
                    or similarity >= 85
                    or (similarity >= 70 and date_hit = 'Y')
                 order by score desc
                 fetch first 10 rows only);
        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_json, '[]');
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end party_candidates_json;

    function party_candidate_count(p_party_type          in varchar2,
                                   p_party_name          in varchar2,
                                   p_registration_number in varchar2,
                                   p_id_number           in varchar2,
                                   p_date                in date,
                                   p_country             in varchar2) return number is
    begin
        return json_array_t.parse(party_candidates_json(p_party_type, p_party_name, p_registration_number,
                                                        p_id_number, p_date, p_country)).get_size;
    end party_candidate_count;

    function request_candidates_json(p_request_id in number) return clob is
        l_req xxcmp_requests%rowtype;
    begin
        select * into l_req from xxcmp_requests where request_id = p_request_id;
        return party_candidates_json(l_req.party_type, l_req.party_name, l_req.registration_number, l_req.id_number,
                                     case l_req.party_type when 'ORGANIZATION' then l_req.incorporation_date
                                                          else l_req.date_of_birth end,
                                     l_req.jurisdiction);
    end request_candidates_json;

    function match_pending(p_request_id in number) return varchar2 is
        l_status xxcmp_requests.match_status%type;
    begin
        select max(match_status) into l_status from xxcmp_requests where request_id = p_request_id;
        return case when l_status = 'PENDING' then 'Y' else 'N' end;
    end match_pending;


    function questionnaire_html(p_request_id in number, p_respondent in varchar2 default 'REQUESTER') return clob is
        l_html    clob;
        l_section varchar2(240) := chr(0);
        l_lang    varchar2(10) := xxfnd_util_pkg.current_lang;
        l_id      varchar2(100);

        procedure add(p_text in varchar2) is
        begin
            dbms_lob.writeappend(l_html, length(p_text), p_text);
        end add;
    begin
        dbms_lob.createtemporary(l_html, true);
        add('<div class="kyc-questionnaire">');
        for q in (select a.question_id, a.answer_option_id, a.answer_text, qu.answer_type, qu.required_flag,
                         nvl(tl.question_text, qu.question_text) as question_text,
                         nvl(nvl(tl.section_name, qu.section_name), 'General') as section_name
                    from xxcmp_request_answers a
                    join xxcmp_questions qu on qu.question_id = a.question_id
                    left join xxcmp_questions_tl tl on tl.question_id = qu.question_id and tl.language_code = l_lang
                   where a.request_id = p_request_id
                     and a.respondent_type = p_respondent
                   -- a section's questions stay together, in the order of its first question
                   order by min(qu.display_sequence) over (partition by nvl(nvl(tl.section_name, qu.section_name), 'General')),
                            qu.display_sequence, qu.question_id) loop
            if q.section_name <> l_section then
                if l_section <> chr(0) then
                    add('</div>');
                end if;
                l_section := q.section_name;
                add('<div class="kyc-section"><h3 class="kyc-section-title">' || apex_escape.html(q.section_name) || '</h3>');
            end if;
            l_id := 'kycq_' || q.question_id;
            add('<fieldset class="kyc-q" data-kyc-q="' || q.question_id || '" data-kyc-type="' || q.answer_type || '">'
                || '<legend class="kyc-q-text">' || apex_escape.html(q.question_text)
                || case when q.required_flag = 'Y' then ' <span class="kyc-q-required" title="Required">*</span>' end
                || '</legend>');
            if q.answer_type in ('YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT') then
                add('<div class="kyc-q-options" role="radiogroup">');
                for o in (select answer_option_id, answer_label
                            from xxcmp_answer_options
                           where question_id = q.question_id and approval_status = 'APPROVED' and enabled_flag = 'Y'
                           order by display_sequence, answer_option_id) loop
                    add('<label class="kyc-q-option"><input type="radio" name="' || l_id || '" value="' || o.answer_option_id || '"'
                        || case when o.answer_option_id = q.answer_option_id then ' checked' end
                        || '> <span>' || apex_escape.html(o.answer_label) || '</span></label>');
                end loop;
                add('</div>');
            elsif q.answer_type = 'TEXT' then
                add('<textarea class="textarea apex-item-textarea kyc-q-input" rows="3" maxlength="4000" aria-label="'
                    || apex_escape.html_attribute(q.question_text) || '">' || apex_escape.html(q.answer_text) || '</textarea>');
            else
                add('<input class="text_field apex-item-text kyc-q-input" type="'
                    || case q.answer_type when 'DATE' then 'date' else 'text" inputmode="decimal' end
                    || '" value="' || apex_escape.html_attribute(q.answer_text) || '" aria-label="'
                    || apex_escape.html_attribute(q.question_text) || '">');
            end if;
            add('</fieldset>');
        end loop;
        if l_section <> chr(0) then
            add('</div>');
        else
            add('<p class="kyc-q-empty">No questions are configured for this counterparty type.</p>');
        end if;
        add('</div>');
        return l_html;
    end questionnaire_html;

    function answers_error(p_request_id in number, p_answers in clob) return varchar2 is
        l_missing varchar2(4000);
    begin
        select listagg(qu.question_text, '; ') within group (order by qu.display_sequence)
          into l_missing
          from xxcmp_request_answers a
          join xxcmp_questions qu on qu.question_id = a.question_id
         where a.request_id = p_request_id
           and a.respondent_type = 'REQUESTER'
           and qu.required_flag = 'Y'
           and not exists (select 1 from json_table(nvl(p_answers, '[]'), '$[*]'
                                            columns (q number path '$.q', o number path '$.o', t varchar2(4000) path '$.t')) j
                            where j.q = a.question_id and (j.o is not null or trim(j.t) is not null));
        return case when l_missing is not null then 'Answer the required questions: ' || l_missing end;
    end answers_error;

    procedure save_answers(p_request_id in number, p_answers in clob) is
        l_status xxcmp_requests.request_status%type;
        l_type   xxcmp_questions.answer_type%type;
        l_option number;
        l_text   varchar2(4000);
    begin
        select request_status into l_status from xxcmp_requests where request_id = p_request_id;
        if l_status <> 'DRAFT' then
            raise_application_error(-20613, 'The request has been submitted; its answers can no longer be changed.');
        end if;
        for j in (select q, o, t from json_table(nvl(p_answers, '[]'), '$[*]'
                          columns (q number path '$.q', o number path '$.o', t varchar2(4000) path '$.t'))) loop
            begin
                select qu.answer_type into l_type
                  from xxcmp_request_answers a join xxcmp_questions qu on qu.question_id = a.question_id
                 where a.request_id = p_request_id and a.respondent_type = 'REQUESTER' and a.question_id = j.q;
            exception
                when no_data_found then
                    raise_application_error(-20614, 'Question ' || j.q || ' does not belong to this request.');
            end;
            l_option := null;
            l_text   := null;
            if l_type in ('YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT') then
                if j.o is not null then
                    select max(answer_option_id) into l_option
                      from xxcmp_answer_options
                     where answer_option_id = j.o and question_id = j.q and approval_status = 'APPROVED' and enabled_flag = 'Y';
                    if l_option is null then
                        raise_application_error(-20615, 'Answer ' || j.o || ' is not an option of question ' || j.q || '.');
                    end if;
                end if;
            elsif l_type = 'NUMBER' and trim(j.t) is not null
                  and validate_conversion(trim(j.t) as number) = 0 then
                raise_application_error(-20616, 'Enter a number for: ' || j.t);
            else
                l_text := trim(j.t);
            end if;
            update xxcmp_request_answers
               set answer_option_id = l_option,
                   answer_text      = case when l_type in ('YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT') then answer_text else l_text end
             where request_id = p_request_id and respondent_type = 'REQUESTER' and question_id = j.q;
        end loop;
    end save_answers;

    function submit_error(p_request_id in number) return varchar2 is
        l_req     xxcmp_requests%rowtype;
        l_missing pls_integer;
        l_error   varchar2(4000);
        l_docs    varchar2(4000);
    begin
        select * into l_req from xxcmp_requests where request_id = p_request_id;
        if l_req.request_status <> 'DRAFT' then
            return 'This request has already been submitted.';
        end if;
        select count(*) into l_missing
          from xxcmp_request_answers a
          join xxcmp_questions q on q.question_id = a.question_id
         where a.request_id = p_request_id and a.respondent_type = 'REQUESTER'
           and q.required_flag = 'Y' and a.answer_option_id is null and a.answer_text is null;
        if l_missing > 0 then
            return l_missing || ' required question(s) are not answered.';
        end if;
        -- reviews of an existing case (monitoring) come with their party: only a requester's new counterparty is checked
        if l_req.parent_case_id is not null then
            return null;
        end if;
        if l_req.party_selection = 'NEW' and l_req.party_id is null then
            l_error := counterparty_error(l_req.party_selection, l_req.party_id, l_req.party_type, l_req.party_name,
                           l_req.registration_number, l_req.entity_type, l_req.incorporation_date, l_req.id_type,
                           l_req.id_number, l_req.jurisdiction, l_req.date_of_birth, l_req.nationality, 'N',
                           l_req.contact_name, l_req.contact_email, l_req.contact_phone);
            if l_error is not null then
                return l_error;
            end if;
        end if;
        -- mandatory documents of the entity type / country (Mandatory Document Rules), attached to the request
        -- or, for an existing party, to the party
        for c in (select c.column_value as category_code,
                         nvl((select max(tl.category_name) from xxfnd_document_categories_tl tl
                               where tl.category_code = c.column_value and tl.language_code = xxfnd_util_pkg.current_lang),
                             (select max(dc.category_name) from xxfnd_document_categories dc
                               where dc.category_code = c.column_value)) as category_name
                    from table(xxcmp_kyc_pkg.mandatory_categories('XXCMP_PARTIES', l_req.jurisdiction, l_req.entity_type)) c
                   where not exists (select 1 from xxfnd_attached_documents_v a
                                      where a.category_code = c.column_value and nvl(a.expired_flag, 'N') = 'N'
                                        and ((a.entity_name = 'XXCMP_REQUESTS' and a.pk1_value = to_char(p_request_id))
                                          or (a.entity_name = 'XXCMP_PARTIES' and a.pk1_value = to_char(l_req.party_id))))) loop
            l_docs := l_docs || case when l_docs is not null then ', ' end || c.category_name;
        end loop;
        if l_docs is not null then
            return 'Attach the mandatory documents: ' || l_docs || '.';
        end if;
        return null;
    end submit_error;

    procedure submit(p_request_id in number) is
        l_error varchar2(4000) := submit_error(p_request_id);
        l_wf    number;
    begin
        if l_error is not null then
            raise_application_error(-20601, l_error);
        end if;
        update xxcmp_requests set request_status = 'SUBMITTED', submitted_date = systimestamp
         where request_id = p_request_id;
        l_wf := apex_workflow.start_workflow(
                    p_application_id => v('APP_ID'),
                    p_static_id      => 'KYC_REQUEST',
                    p_detail_pk      => to_char(p_request_id));
        update xxcmp_requests set workflow_id = l_wf where request_id = p_request_id;
    end submit;

    function new_party(p_req in xxcmp_requests%rowtype) return number is
        l_id number;
    begin
        insert into xxcmp_parties (party_type, party_name, registration_number, jurisdiction, entity_type, incorporation_date,
                                   date_of_birth, nationality, id_type, id_number, data_provenance)
        values (p_req.party_type, p_req.party_name, p_req.registration_number, p_req.jurisdiction, p_req.entity_type,
                p_req.incorporation_date, p_req.date_of_birth, p_req.nationality, p_req.id_type, p_req.id_number,
                'SELF_DECLARED')
        returning party_id into l_id;
        -- the contact details given by the requesting department: the party's main email / phone and a contact person
        update xxcmp_parties set email = p_req.contact_email, phone = p_req.contact_phone where party_id = l_id;
        if p_req.contact_name is not null then
            insert into xxcmp_party_contacts (party_id, contact_type, contact_value, contact_name, email, phone, primary_flag)
            values (l_id, 'PERSON', p_req.contact_name, p_req.contact_name, p_req.contact_email, p_req.contact_phone, 'Y');
        end if;
        return l_id;
    end new_party;

    -- The request's party: the one the requester chose; else a new party when nothing resembles it; else
    -- Compliance decides (PENDING) - a new counterparty is never linked to an existing party automatically.
    procedure link_party(p_req in out xxcmp_requests%rowtype) is
    begin
        if p_req.party_id is not null then
            p_req.match_status := nvl(p_req.match_status, 'SELECTED');
        elsif party_candidate_count(p_req.party_type, p_req.party_name, p_req.registration_number, p_req.id_number,
                                    case p_req.party_type when 'ORGANIZATION' then p_req.incorporation_date
                                                          else p_req.date_of_birth end,
                                    p_req.jurisdiction) > 0 then
            p_req.match_status := 'PENDING';
        else
            p_req.party_id     := new_party(p_req);
            p_req.match_status := 'NEW';
        end if;
        update xxcmp_requests set party_id = p_req.party_id, match_status = p_req.match_status
         where request_id = p_req.request_id;
    end link_party;

    procedure resolve_match(p_request_id in number, p_party_id in number default null, p_note in varchar2 default null) is
        l_req   xxcmp_requests%rowtype;
        l_party xxcmp_parties%rowtype;
    begin
        if not xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') then
            raise_application_error(-20619, 'Only Compliance can decide whether a counterparty is an existing party.');
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_req from xxcmp_requests where request_id = p_request_id for update;
        if nvl(l_req.match_status, '#') <> 'PENDING' then
            raise_application_error(-20620, 'The counterparty of request ' || l_req.request_number || ' has already been decided.');
        end if;
        if p_party_id is not null then
            select * into l_party from xxcmp_parties where party_id = p_party_id for update;
            if l_party.party_type <> l_req.party_type then
                raise_application_error(-20621, 'An organisation cannot be merged into an individual, or the reverse.');
            end if;
            -- merge: the party keeps its data; empty fields are completed from the request
            update xxcmp_parties
               set registration_number = case when party_type = 'ORGANIZATION' then nvl(registration_number, l_req.registration_number) end,
                   entity_type         = case when party_type = 'ORGANIZATION' then nvl(entity_type, l_req.entity_type) end,
                   incorporation_date  = case when party_type = 'ORGANIZATION' then nvl(incorporation_date, l_req.incorporation_date) end,
                   date_of_birth       = case when party_type = 'PERSON' then nvl(date_of_birth, l_req.date_of_birth) end,
                   nationality         = case when party_type = 'PERSON' then nvl(nationality, l_req.nationality) end,
                   id_type             = case when party_type = 'PERSON' then nvl(id_type, l_req.id_type) end,
                   id_number           = case when party_type = 'PERSON' then nvl(id_number, l_req.id_number) end,
                   jurisdiction        = nvl(jurisdiction, l_req.jurisdiction)
             where party_id = p_party_id;
            l_req.party_id     := p_party_id;
            l_req.match_status := 'MERGED';
        else
            l_req.party_id     := new_party(l_req);
            l_req.match_status := 'CONFIRMED_NEW';
        end if;
        update xxcmp_requests
           set party_id = l_req.party_id, match_status = l_req.match_status, match_note = p_note,
               match_resolved_by = xxfnd_util_pkg.current_user, match_resolved_date = systimestamp
         where request_id = p_request_id;
        -- workflow 1.2 decides this inside the checklist review; requests started on 1.1 wait on a
        -- Counterparty Match task: completing it moves them on to the checklist
        xxfnd_task_pkg.complete_open('COUNTERPARTY_MATCH', to_char(p_request_id));
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end resolve_match;

    procedure evaluate(p_request_id in number) is
        l_req      xxcmp_requests%rowtype;
        l_score    number;
        l_critical pls_integer;
        l_waiver   pls_integer;
        l_low      number;
        l_outcome  varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_req from xxcmp_requests where request_id = p_request_id for update;
        link_party(l_req);
        if l_req.request_type <> 'NEW_ONBOARDING' or l_req.questionnaire_code is null then
            l_outcome := 'ASSIGNED';                          -- reviews always go to Compliance
        else
            update xxcmp_request_answers a
               set risk_points = (select o.risk_points from xxcmp_answer_options o where o.answer_option_id = a.answer_option_id)
             where a.request_id = p_request_id and a.respondent_type = 'REQUESTER';
            select nvl(sum(a.risk_points), 0),
                   count(case when o.critical_flag = 'Y' then 1 end),
                   count(case when q.gate_question_flag = 'Y' and o.waiver_qualifying_flag = 'Y' then 1 end)
              into l_score, l_critical, l_waiver
              from xxcmp_request_answers a
              join xxcmp_questions q on q.question_id = a.question_id
              left join xxcmp_answer_options o on o.answer_option_id = a.answer_option_id
             where a.request_id = p_request_id and a.respondent_type = 'REQUESTER';
            select low_risk_max_score into l_low from xxcmp_questionnaires where questionnaire_code = l_req.questionnaire_code;
            l_outcome := case when l_critical > 0 then 'ASSIGNED'
                              when l_waiver > 0 then 'NOT_REQUIRED'
                              when l_low is not null and l_score <= l_low then 'AUTO_APPROVED'
                              else 'ASSIGNED' end;
            update xxcmp_requests set intake_score = l_score, intake_critical_flag = case when l_critical > 0 then 'Y' else 'N' end
             where request_id = p_request_id;
        end if;
        if l_req.match_status = 'PENDING' then
            l_outcome := 'ASSIGNED';     -- possibly an existing party: Compliance decides
        end if;
        update xxcmp_requests
           set intake_outcome = l_outcome,
               request_status = case when l_outcome = 'ASSIGNED' then 'IN_PROGRESS' else request_status end
         where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end evaluate;

    function outcome(p_request_id in number) return varchar2 is
        l_outcome varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select intake_outcome into l_outcome from xxcmp_requests where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_outcome;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end outcome;

    procedure close_without_case(p_request_id in number) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests set request_status = 'COMPLETED', completed_date = systimestamp
         where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end close_without_case;

    procedure create_case(p_request_id in number) is
        l_case number;
    begin
        if match_pending(p_request_id) = 'Y' then
            raise_application_error(-20622, 'The counterparty of the request is not decided yet: no case can be opened.');
        end if;
        l_case := xxcmp_case_pkg.create_case(p_request_id);
    end create_case;

    procedure reject(p_request_id in number) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests set request_status = 'REJECTED', completed_date = systimestamp
         where request_id = p_request_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end reject;

    function stage(p_request_id in number) return varchar2 is
        l_status  varchar2(30);
        l_outcome varchar2(30);
    begin
        select request_status, intake_outcome into l_status, l_outcome from xxcmp_requests where request_id = p_request_id;
        return case
                   when l_status = 'DRAFT'                                  then 'Draft'
                   when l_status = 'SUBMITTED' and l_outcome is null        then 'Processing'
                   when l_status in ('SUBMITTED','IN_PROGRESS')            then 'In Progress'
                   when l_status = 'COMPLETED' and l_outcome = 'NOT_REQUIRED' then 'Completed - KYC not required'
                   when l_status = 'COMPLETED' and l_outcome = 'AUTO_APPROVED' then 'Completed - approved'
                   when l_status = 'COMPLETED'                              then 'Completed'
                   when l_status = 'REJECTED'                               then 'Rejected'
                   else initcap(l_status)
               end;
    end stage;

    function start_review(p_case_id in number, p_request_type in varchar2, p_trigger_source in varchar2,
                          p_justification in varchar2) return number is
        l_id    number;
        l_party xxcmp_parties%rowtype;
        l_case  xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        select * into l_party from xxcmp_parties where party_id = l_case.party_id;
        l_id := create_request(p_party_type          => l_party.party_type,
                               p_party_name          => l_party.party_name,
                               p_registration_number => l_party.registration_number,
                               p_jurisdiction        => l_party.jurisdiction,
                               p_entity_type         => l_party.entity_type,
                               p_date_of_birth       => l_party.date_of_birth,
                               p_nationality         => l_party.nationality,
                               p_justification       => p_justification,
                               p_request_type        => p_request_type,
                               p_trigger_source      => p_trigger_source,
                               p_parent_request_id   => l_case.request_id,
                               p_parent_case_id      => p_case_id,
                               p_party_id            => l_case.party_id);
        submit(l_id);
        xxfnd_vpd_pkg.end_trusted;
        return l_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end start_review;

end xxcmp_request_pkg;
/

--------------------------------------------------------------------------------
-- Cases
--------------------------------------------------------------------------------
create or replace package body xxcmp_case_pkg as

    -- Numeric KYC parameter maintained by administrators (lookup KYC_PARAMETER, value in TAG).
    function param(p_code in varchar2, p_default in number) return number is
        l_value number;
    begin
        select max(to_number(tag default null on conversion error)) into l_value from xxfnd_lookup_values
         where lookup_type = 'KYC_PARAMETER' and lookup_code = p_code and enabled_flag = 'Y';
        return nvl(l_value, p_default);
    end param;

    function get_case(p_case_id in number) return xxcmp_cases%rowtype is
        l_case xxcmp_cases%rowtype;
    begin
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        return l_case;
    end get_case;

    function create_case(p_request_id in number, p_assigned_to in varchar2 default null) return number is
        l_req  xxcmp_requests%rowtype;
        l_id   number;
        l_wf   number;
        l_sla  number := param('CASE_SLA_DAYS', 10);   -- private function: not callable inside SQL
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_req from xxcmp_requests where request_id = p_request_id;
        insert into xxcmp_cases (case_number, request_id, party_id, parent_case_id, assigned_to, sla_due_date)
        values ('CASE-' || lpad(xxcmp_case_number_s.nextval, 6, '0'), p_request_id, l_req.party_id, l_req.parent_case_id,
                upper(p_assigned_to), trunc(sysdate) + l_sla)
        returning case_id into l_id;
        -- the officer's investigation questionnaire
        insert into xxcmp_request_answers (request_id, case_id, respondent_type, question_id)
        select p_request_id, l_id, 'OFFICER', q.question_id
          from xxcmp_questions q
          join xxcmp_questionnaires qn on qn.questionnaire_code = q.questionnaire_code
         where qn.audience = 'OFFICER' and qn.enabled_flag = 'Y' and q.enabled_flag = 'Y'
           and not exists (select 1 from xxcmp_request_answers a
                            where a.request_id = p_request_id and a.respondent_type = 'OFFICER' and a.question_id = q.question_id);
        update xxcmp_requests set request_status = 'IN_PROGRESS' where request_id = p_request_id;
        l_wf := apex_workflow.start_workflow(
                    p_application_id => v('APP_ID'),
                    p_static_id      => 'KYC_CASE',
                    -- the requester (or whoever opened a manual case) initiates; separation of duties excludes them
                    p_initiator      => coalesce(l_req.requester_user_name, nullif(v('APP_USER'), 'nobody')),
                    p_detail_pk      => to_char(l_id));
        update xxcmp_cases set workflow_id = l_wf where case_id = l_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end create_case;

    function create_manual_case(p_party_id in number, p_justification in varchar2) return number is
        l_party xxcmp_parties%rowtype;
        l_req   number;
    begin
        select * into l_party from xxcmp_parties where party_id = p_party_id;
        l_req := xxcmp_request_pkg.create_request(
                     p_party_type          => l_party.party_type,
                     p_party_name          => l_party.party_name,
                     p_registration_number => l_party.registration_number,
                     p_jurisdiction        => l_party.jurisdiction,
                     p_entity_type         => l_party.entity_type,
                     p_date_of_birth       => l_party.date_of_birth,
                     p_nationality         => l_party.nationality,
                     p_justification       => p_justification,
                     p_request_type        => 'EVENT_TRIGGERED_REVIEW',
                     p_trigger_source      => 'MANUAL',
                     p_party_id            => p_party_id);
        update xxcmp_requests set request_status = 'IN_PROGRESS', intake_outcome = 'ASSIGNED', submitted_date = systimestamp
         where request_id = l_req;
        return create_case(l_req, xxfnd_util_pkg.current_user);
    end create_manual_case;

    procedure assign(p_case_id in number, p_user_name in varchar2) is
    begin
        update xxcmp_cases set assigned_to = upper(p_user_name) where case_id = p_case_id and case_status = 'INVESTIGATION';
        if sql%rowcount = 0 then
            raise_application_error(-20611, 'Only a case under investigation can be reassigned.');
        end if;
    end assign;

    function investigation_owners(p_case_id in number) return varchar2 is
        l_case xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_case.assigned_to, xxfnd_task_pkg.users_with_privilege('CASES', 'MANAGE'));
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end investigation_owners;

    function matrix(p_case in xxcmp_cases%rowtype) return xxcmp_approval_matrix%rowtype is
        l_row xxcmp_approval_matrix%rowtype;
    begin
        select * into l_row from xxcmp_approval_matrix where risk_tier = p_case.risk_tier;
        return l_row;
    exception
        when no_data_found then
            raise_application_error(-20612, 'The approval matrix has no row for risk tier ' || p_case.risk_tier || '.');
    end matrix;

    function required_levels(p_case_id in number) return number is
        l_case xxcmp_cases%rowtype := get_case(p_case_id);
        l_m    xxcmp_approval_matrix%rowtype := matrix(l_case);
    begin
        return case when l_case.enhanced_kyc_flag = 'Y' then greatest(l_m.required_levels, 2) else l_m.required_levels end;
    end required_levels;

    function level_role(p_case_id in number, p_level in number) return varchar2 is
        l_m xxcmp_approval_matrix%rowtype := matrix(get_case(p_case_id));
    begin
        return case p_level when 1 then l_m.level1_role_code
                            else nvl(l_m.level2_role_code, 'HEAD_OF_COMPLIANCE') end;
    end level_role;

    function sar_gate(p_case_id in number) return varchar2 is
        l_case xxcmp_cases%rowtype := get_case(p_case_id);
    begin
        return case when l_case.enhanced_kyc_flag = 'Y' then 'Y' else nvl(matrix(l_case).sar_gate_flag, 'N') end;
    end sar_gate;

    function is_editable(p_case_id in number) return varchar2 is
        l_status xxcmp_cases.case_status%type;
    begin
        select max(case_status) into l_status from xxcmp_cases where case_id = p_case_id;
        return case when l_status = 'INVESTIGATION' and xxfnd_privilege_pkg.has_privilege('CASES', 'MANAGE')
                    then 'Y' else 'N' end;
    end is_editable;

    -- Users who investigated or already decided this case, with the roles they acted under.
    function prior_actors(p_case_id in number) return apex_t_varchar2 is
        l_list apex_t_varchar2;
    begin
        select upper(u) bulk collect into l_list from (
            select assigned_to u from xxcmp_cases where case_id = p_case_id and assigned_to is not null
            union
            select actual_owner from apex_tasks
             where task_def_static_id = 'CASE_INVESTIGATION' and detail_pk = to_char(p_case_id) and actual_owner is not null
            union
            select decided_by from xxcmp_case_decisions where case_id = p_case_id);
        return l_list;
    end prior_actors;

    function level_approvers(p_case_id in number) return varchar2 is
        l_case  xxcmp_cases%rowtype;
        l_role  varchar2(30);
        l_prior apex_t_varchar2;
        l_out   varchar2(32767);
        l_roles apex_t_varchar2;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case  := get_case(p_case_id);
        l_role  := level_role(p_case_id, l_case.current_level);
        l_prior := prior_actors(p_case_id);
        for u in (select distinct ur.user_name from xxfnd_user_roles_v ur
                   where ur.role_code = l_role and ur.active_flag = 'Y'
                   order by ur.user_name) loop
            -- four eyes: nobody decides a case they investigated or already decided,
            -- nor while holding a role that may never be combined with this one
            select role_code bulk collect into l_roles from xxcmp_case_decisions
             where case_id = p_case_id and decided_by = u.user_name and role_code is not null;
            if u.user_name not member of l_prior
               and not xxfnd_security_pkg.sod_conflict(l_role, l_roles, u.user_name) then
                l_out := l_out || case when l_out is not null then ',' end || u.user_name;
            end if;
        end loop;
        xxfnd_vpd_pkg.end_trusted;
        return l_out;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end level_approvers;

    function submit_error(p_case_id in number) return varchar2 is
        l_case  xxcmp_cases%rowtype := get_case(p_case_id);
        l_count pls_integer;
    begin
        if l_case.case_status <> 'INVESTIGATION' then
            return 'The case is not under investigation.';
        end if;
        if l_case.risk_tier is null then
            return 'Set the risk classification.';
        end if;
        select count(*) into l_count from xxcmp_screenings where case_id = p_case_id;
        if l_count = 0 then
            return 'Record at least one screening.';
        end if;
        select count(*) into l_count from xxcmp_rfis
         where entity_name = 'XXCMP_CASES' and pk1_value = to_char(p_case_id)
           and continue_other_work_flag = 'N' and rfi_status in ('WAITING_FOR_INFORMATION','ON_HOLD_PENDING');
        if l_count > 0 then
            return 'A request for information that pauses the case is still open.';
        end if;
        if l_case.enhanced_kyc_flag = 'Y' then
            select count(*) into l_count
              from xxcmp_request_answers a
              join xxcmp_questions q on q.question_id = a.question_id
             where a.case_id = p_case_id and a.respondent_type = 'OFFICER'
               and q.section_name = 'Enhanced Due Diligence'
               and a.answer_option_id is null and a.answer_text is null;
            if l_count > 0 then
                return 'Enhanced KYC: answer the source of funds and source of wealth questions.';
            end if;
        end if;
        return null;
    end submit_error;

    procedure submit_for_approval(p_case_id in number) is
        l_error varchar2(4000) := submit_error(p_case_id);
    begin
        if l_error is not null then
            raise_application_error(-20613, l_error);
        end if;
        -- completing the investigation task moves the KYC_CASE workflow on
        xxfnd_task_pkg.complete_open('CASE_INVESTIGATION', to_char(p_case_id));
    end submit_for_approval;

    function approval_error(p_case_id in number) return varchar2 is
        l_case    xxcmp_cases%rowtype := get_case(p_case_id);
        l_missing pls_integer;
    begin
        if l_case.case_status <> 'PENDING_APPROVAL' then
            return 'The case is not waiting for approval.';
        end if;
        if sar_gate(p_case_id) = 'Y' and l_case.sar_required_flag is null then
            return 'Record whether a Suspicious Activity Report is required.';
        end if;
        if xxfnd_util_pkg.current_user member of prior_actors(p_case_id) then
            return 'You investigated or already decided this case.';
        end if;
        -- every mandatory document of the party must be verified in this case
        select count(*) into l_missing
          from table(xxcmp_kyc_pkg.mandatory_categories('XXCMP_PARTIES',
                         (select jurisdiction from xxcmp_parties where party_id = l_case.party_id),
                         (select entity_type from xxcmp_parties where party_id = l_case.party_id))) m
         where not exists (
                 select 1
                   from xxfnd_attached_documents ad
                   join xxcmp_doc_verifications v on v.attached_document_id = ad.attached_document_id
                  where ad.entity_name = 'XXCMP_PARTIES' and ad.pk1_value = to_char(l_case.party_id)
                    and ad.category_code = m.column_value
                    and v.case_id = p_case_id and v.verification_status = 'VERIFIED');
        if l_missing > 0 then
            return l_missing || ' mandatory document(s) are not verified for this case.';
        end if;
        return null;
    end approval_error;

    procedure record_decision(p_case_id in number, p_outcome in varchar2, p_comments in varchar2, p_task_id in number) is
        l_case xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_case := get_case(p_case_id);
        insert into xxcmp_case_decisions (case_id, level_no, role_code, decided_by, outcome, comments, task_id)
        values (p_case_id, l_case.current_level, level_role(p_case_id, l_case.current_level),
                xxfnd_util_pkg.current_user, p_outcome, p_comments, p_task_id);
        if p_outcome = 'APPROVED' then
            update xxcmp_cases set current_level = current_level + 1 where case_id = p_case_id;
        end if;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end record_decision;

    function next_review_date(p_case_id in number) return date is
        l_case   xxcmp_cases%rowtype := get_case(p_case_id);
        l_months number;
    begin
        select max(to_number(tag default null on conversion error)) into l_months
          from xxfnd_lookup_values where lookup_type = 'RISK_TIER' and lookup_code = l_case.risk_tier;
        if l_case.pep_flag = 'Y' then
            l_months := least(nvl(l_months, 12), param('PEP_REVIEW_MONTHS', 12));
        end if;
        return add_months(trunc(sysdate), nvl(l_months, 12));
    end next_review_date;

    procedure start_approval(p_case_id in number) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_cases
           set case_status = 'PENDING_APPROVAL', current_level = 1, investigation_completed_date = systimestamp
         where case_id = p_case_id;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end start_approval;

    function has_next_level(p_case_id in number) return varchar2 is
        l_result varchar2(1);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_result := case when get_case(p_case_id).current_level <= required_levels(p_case_id) then 'Y' else 'N' end;
        xxfnd_vpd_pkg.end_trusted;
        return l_result;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end has_next_level;

    procedure close_case(p_case_id in number, p_decision in varchar2) is
        l_case xxcmp_cases%rowtype := get_case(p_case_id);
        -- computed first: the function reads XXCMP_CASES, which would be mutating inside the UPDATE
        l_next date := case when p_decision = 'APPROVED' then nvl(l_case.next_review_date, next_review_date(p_case_id)) end;
    begin
        update xxcmp_cases
           set case_status      = p_decision,
               decision         = p_decision,
               decision_date    = systimestamp,
               next_review_date = l_next,
               closed_date      = systimestamp
         where case_id = p_case_id;
        update xxcmp_requests set request_status = 'COMPLETED', completed_date = systimestamp
         where request_id = l_case.request_id;
    end close_case;

    procedure approve_case(p_case_id in number) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        close_case(p_case_id, 'APPROVED');
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end approve_case;

    procedure reject_case(p_case_id in number) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        close_case(p_case_id, 'REJECTED');
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end reject_case;

    procedure apply_screening(p_case_id in number) is
        l_pep pls_integer;
        l_hit pls_integer;
    begin
        select count(case when pep_flag = 'Y' then 1 end), count(case when match_status = 'CONFIRMED_MATCH' then 1 end)
          into l_pep, l_hit
          from xxcmp_screenings where case_id = p_case_id;
        update xxcmp_cases
           set pep_flag          = case when l_pep > 0 then 'Y' else pep_flag end,
               enhanced_kyc_flag = case when l_pep > 0 or l_hit > 0 then 'Y' else enhanced_kyc_flag end
         where case_id = p_case_id and case_status = 'INVESTIGATION';
    end apply_screening;

end xxcmp_case_pkg;
/

-- A closed case cannot change any more (case closure locks it).
create or replace trigger xxcmp_cases_lock
before update on xxcmp_cases
for each row
when (old.closed_date is not null)
begin
    -- a party merge (XXCMP_PARTY_PKG.MERGE_PARTIES) only re-points the case to the party that is kept
    if updating('PARTY_ID') and not (updating('CASE_STATUS') or updating('DECISION') or updating('RISK_TIER')
                                     or updating('CLOSED_DATE') or updating('CONDITIONS') or updating('NEXT_REVIEW_DATE')
                                     or updating('ASSIGNED_TO') or updating('SAR_REQUIRED_FLAG') or updating('REQUEST_ID')) then
        return;
    end if;
    raise_application_error(-20614, 'Case ' || :old.case_number || ' is closed and cannot be changed.');
end;
/

-- ==== 16e-party-pkg.sql
--------------------------------------------------------------------------------
-- 16e Party logic (party feature: pages 21, 23)
--   XXCMP_PARTY_PKG: create a party from another screen (owner / officer) and merge a
--   duplicate party into another one (Compliance). Runs after 16b/16c: the merge re-points
--   requests, cases, screenings, alerts, notes and beneficial-owner decisions.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxcmp_party_pkg authid definer as

    -- A new party created from another screen (for example a new owner / officer on page 23). Requires
    -- Parties - Create. Refused when a party with the same registration / identity number and country exists.
    function create_party(p_party_type          in varchar2,
                          p_party_name          in varchar2,
                          p_jurisdiction        in varchar2 default null,
                          p_registration_number in varchar2 default null,
                          p_date_of_birth       in date     default null) return number;

    -- Compliance merges the duplicate P_FROM_PARTY_ID into P_INTO_PARTY_ID (Parties - Manage): requests, cases,
    -- screenings, alerts, notes, beneficial-owner decisions, contacts, relationships and documents move to the
    -- kept party; its empty details are completed from the duplicate; the duplicate is disabled and points to it.
    procedure merge_parties(p_from_party_id in number, p_into_party_id in number, p_note in varchar2 default null);

    -- Y when the party exists and is enabled (a merged or disabled party is not edited or merged again).
    function is_enabled(p_party_id in number) return varchar2;

end xxcmp_party_pkg;
/

create or replace package body xxcmp_party_pkg as

    function create_party(p_party_type          in varchar2,
                          p_party_name          in varchar2,
                          p_jurisdiction        in varchar2 default null,
                          p_registration_number in varchar2 default null,
                          p_date_of_birth       in date     default null) return number is
        l_id    number;
        l_exact varchar2(30);
    begin
        if not xxfnd_privilege_pkg.has_privilege('PARTIES', 'CREATE') then
            raise_application_error(-20701, 'You are not allowed to create parties.');
        elsif p_party_type not in ('ORGANIZATION', 'PERSON') or p_party_type is null then
            raise_application_error(-20702, 'Choose whether the new party is an organisation or an individual.');
        elsif trim(p_party_name) is null then
            raise_application_error(-20703, 'Enter the name of the new party.');
        elsif p_date_of_birth > trunc(sysdate) then
            raise_application_error(-20704, 'The date of birth cannot be in the future.');
        end if;
        if p_party_type = 'ORGANIZATION' and trim(p_registration_number) is not null and p_jurisdiction is not null then
            -- same registration number (ignoring spaces and punctuation) and country = the same organisation
            select min(party_number) into l_exact
              from xxcmp_parties
             where party_type = 'ORGANIZATION' and enabled_flag = 'Y' and jurisdiction = p_jurisdiction
               and upper(regexp_replace(registration_number, '[^[:alnum:]]', ''))
                 = upper(regexp_replace(p_registration_number, '[^[:alnum:]]', ''));
            if l_exact is not null then
                raise_application_error(-20705, 'Party ' || l_exact || ' already has this registration number and country: choose it instead.');
            end if;
        end if;
        insert into xxcmp_parties (party_type, party_name, jurisdiction, registration_number, date_of_birth, data_provenance)
        values (p_party_type, trim(p_party_name), p_jurisdiction,
                case when p_party_type = 'ORGANIZATION' then trim(p_registration_number) end,
                case when p_party_type = 'PERSON' then p_date_of_birth end, 'SELF_DECLARED')
        returning party_id into l_id;
        return l_id;
    end create_party;

    procedure merge_parties(p_from_party_id in number, p_into_party_id in number, p_note in varchar2 default null) is
        l_from xxcmp_parties%rowtype;
        l_into xxcmp_parties%rowtype;
    begin
        if not xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') then
            raise_application_error(-20711, 'Only Compliance can merge parties.');
        elsif p_from_party_id is null or p_into_party_id is null or p_from_party_id = p_into_party_id then
            raise_application_error(-20712, 'Choose another party to merge into.');
        end if;
        select * into l_from from xxcmp_parties where party_id = p_from_party_id for update;
        select * into l_into from xxcmp_parties where party_id = p_into_party_id for update;
        if l_from.party_type <> l_into.party_type then
            raise_application_error(-20713, 'An organisation cannot be merged into an individual, or the reverse.');
        elsif l_from.enabled_flag = 'N' or l_into.enabled_flag = 'N' then
            raise_application_error(-20714, 'Both parties must be enabled.');
        end if;

        -- everything recorded against the duplicate now belongs to the kept party
        update xxcmp_requests   set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_cases      set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_screenings set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_alerts     set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_case_notes set related_party_id = p_into_party_id where related_party_id = p_from_party_id;
        -- one beneficial-owner decision per case and owner
        delete from xxcmp_ubo_determinations u
         where u.owner_party_id = p_from_party_id
           and exists (select 1 from xxcmp_ubo_determinations k where k.case_id = u.case_id and k.owner_party_id = p_into_party_id);
        update xxcmp_ubo_determinations set owner_party_id = p_into_party_id where owner_party_id = p_from_party_id;
        -- contacts move as non-primary (the kept party keeps its primary contacts)
        update xxcmp_party_contacts set party_id = p_into_party_id, primary_flag = 'N' where party_id = p_from_party_id;
        -- relationships: a relationship between the two parties would point to itself
        delete from xxcmp_party_relationships
         where (subject_party_id = p_from_party_id and object_party_id = p_into_party_id)
            or (subject_party_id = p_into_party_id and object_party_id = p_from_party_id);
        update xxcmp_party_relationships set subject_party_id = p_into_party_id where subject_party_id = p_from_party_id;
        update xxcmp_party_relationships set object_party_id  = p_into_party_id where object_party_id  = p_from_party_id;
        -- documents
        update xxfnd_attached_documents set pk1_value = to_char(p_into_party_id)
         where entity_name = 'XXCMP_PARTIES' and pk1_value = to_char(p_from_party_id);

        -- the kept party's empty details are completed from the duplicate
        update xxcmp_parties
           set registration_number = nvl(registration_number, l_from.registration_number),
               entity_type         = nvl(entity_type, l_from.entity_type),
               incorporation_date  = nvl(incorporation_date, l_from.incorporation_date),
               date_of_birth       = nvl(date_of_birth, l_from.date_of_birth),
               nationality         = nvl(nationality, l_from.nationality),
               id_type             = nvl(id_type, l_from.id_type),
               id_number           = nvl(id_number, l_from.id_number),
               jurisdiction        = nvl(jurisdiction, l_from.jurisdiction),
               email               = nvl(email, l_from.email),
               phone               = nvl(phone, l_from.phone),
               website             = nvl(website, l_from.website),
               fax                 = nvl(fax, l_from.fax)
         where party_id = p_into_party_id;
        update xxcmp_parties
           set enabled_flag = 'N', merged_into_party_id = p_into_party_id, merge_note = substr(p_note, 1, 1000)
         where party_id = p_from_party_id;
    end merge_parties;

    function is_enabled(p_party_id in number) return varchar2 is
        l_flag xxcmp_parties.enabled_flag%type;
    begin
        select max(enabled_flag) into l_flag from xxcmp_parties where party_id = p_party_id;
        return case when l_flag = 'Y' then 'Y' else 'N' end;
    end is_enabled;

end xxcmp_party_pkg;
/


-- ==== checks
select object_name, object_type, status from user_objects
 where object_name in ('XXCMP_PARTY_PKG', 'XXCMP_KYC_PKG', 'XXCMP_REQUEST_PKG', 'XXCMP_CASE_PKG', 'XXCMP_CASES_LOCK') order by 1, 2;
select table_name, column_name from user_tab_columns
 where (table_name = 'XXCMP_PARTIES' and column_name in ('EMAIL', 'PHONE', 'WEBSITE', 'FAX', 'MERGED_INTO_PARTY_ID'))
    or (table_name = 'XXCMP_PARTY_CONTACTS' and column_name in ('JOB_TITLE', 'EMAIL', 'PHONE')) order by 1, 2;
