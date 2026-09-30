create or replace package body xxcus.xxcmp_kyc_pkg as

    function mandatory_categories (
        p_entity_name  in varchar2,
        p_jurisdiction in varchar2,
        p_entity_type  in varchar2
    ) return apex_t_varchar2 is
        l_result apex_t_varchar2;
    begin
        select
            category_code
        bulk collect
        into l_result
        from
            (
                select
                    r.category_code,
                    r.mandatory_flag,
                    row_number()
                    over(partition by r.category_code
                         order by
                                 case
                                     when r.jurisdiction is not null then
                                         0
                                     else
                                         1
                                 end
                                 +
                                 case
                                     when r.entity_type is not null then
                                         0
                                     else
                                         1
                                 end,
                                 case
                                     when r.jurisdiction is not null then
                                         0
                                     else
                                         1
                                 end, r.priority
                    ) rn
                from
                    xxcmp_attachment_rules r
                where
                        r.entity_name = p_entity_name
                    and r.enabled_flag = 'Y'
                    and r.approval_status = 'APPROVED'
                    and ( r.jurisdiction is null
                          or r.jurisdiction = p_jurisdiction )
                    and ( r.entity_type is null
                          or r.entity_type = p_entity_type )
            )
        where
                rn = 1
            and mandatory_flag = 'Y'
        order by
            category_code;

        return l_result;
    end mandatory_categories;

    function missing_categories (
        p_entity_name  in varchar2,
        p_pk1_value    in varchar2,
        p_jurisdiction in varchar2,
        p_entity_type  in varchar2
    ) return apex_t_varchar2 is

        l_required apex_t_varchar2 := mandatory_categories(p_entity_name, p_jurisdiction, p_entity_type);
        l_missing  apex_t_varchar2 := apex_t_varchar2();
        l_count    pls_integer;
    begin
        for i in 1..l_required.count loop
            select
                count(*)
            into l_count
            from
                xxfnd_attached_documents_v v
            where
                    v.entity_name = p_entity_name
                and v.pk1_value = p_pk1_value
                and v.category_code = l_required(i)
                and v.expired_flag = 'N'
                and ( v.upload_status in ( 'STORED', 'NOT_APPLICABLE' ) );

            if l_count = 0 then
                l_missing.extend;
                l_missing(l_missing.count) := l_required(i);
            end if;

        end loop;

        return l_missing;
    end missing_categories;

    function normalise (
        p_name in varchar2
    ) return varchar2 is
        l_name varchar2(4000) := ' '
                                 || upper(p_name)
                                 || ' ';
    begin
        l_name := regexp_replace(l_name, '[^A-Z0-9 ]', ' ');
        l_name := regexp_replace(l_name, ' (LTD|LIMITED|LLC|INC|INCORPORATED|CORP|CORPORATION|CO|COMPANY|PLC|SA|AG|GMBH|WLL|FZE|FZCO|FZ LLC|BV|NV) '
        , ' ');
        return trim(regexp_replace(l_name, ' +', ' '));
    end normalise;

    function name_similarity (
        p_name_1 in varchar2,
        p_name_2 in varchar2
    ) return number
        deterministic
    is
    begin
        if p_name_1 is null
           or p_name_2 is null then
            return 0;
        end if;
        return utl_match.jaro_winkler_similarity(
            normalise(p_name_1),
            normalise(p_name_2)
        );
    end name_similarity;

    function exact_party_match (
        p_party_type          in varchar2,
        p_party_name          in varchar2,
        p_registration_number in varchar2 default null,
        p_jurisdiction        in varchar2 default null,
        p_date_of_birth       in date default null
    ) return number is
        l_id number;
    begin
        if
            p_party_type = 'ORGANIZATION'
            and p_registration_number is not null
        then
            select
                min(party_id)
            into l_id
            from
                xxcmp_parties
            where
                    party_type = 'ORGANIZATION'
                and upper(replace(registration_number, ' ')) = upper(replace(p_registration_number, ' '))
                and nvl(jurisdiction, '#') = nvl(p_jurisdiction, '#')
                and enabled_flag = 'Y';

        elsif
            p_party_type = 'PERSON'
            and p_date_of_birth is not null
        then
            select
                min(party_id)
            into l_id
            from
                xxcmp_parties
            where
                    party_type = 'PERSON'
                and date_of_birth = p_date_of_birth
                and upper(party_name) = upper(p_party_name)
                and enabled_flag = 'Y';

        end if;

        return l_id;
    end exact_party_match;

    function hash_token (
        p_token in varchar2
    ) return varchar2 is
    begin
        return rawtohex(dbms_crypto.hash(
            utl_i18n.string_to_raw(p_token, 'AL32UTF8'),
            dbms_crypto.hash_sh256
        ));
    end hash_token;

    procedure create_rfi (
        p_entity_name         in varchar2,
        p_pk1_value           in varchar2,
        p_recipient_type      in varchar2,
        p_rfi_category        in varchar2,
        p_description         in varchar2,
        p_continue_other_work in varchar2,
        p_due_date            in date,
        p_recipient_user_name in varchar2 default null,
        p_party_contact_id    in number default null,
        p_rfi_id              out number,
        p_token               out varchar2
    ) is
        l_hash    varchar2(128);
        l_task_id number;
    begin
        xxfnd_util_pkg.assert_lookup('RFI_CATEGORY', p_rfi_category, 'RFI category');
        if
            p_due_date is not null
            and p_due_date < trunc(sysdate)
        then
            raise_application_error(-20501, 'The due date cannot be in the past.');
        end if;

        if p_recipient_type = 'EXTERNAL_PARTY' then
            p_token := lower(rawtohex(dbms_crypto.randombytes(32)));
            l_hash := hash_token(p_token);
        end if;

        insert into xxcmp_rfis (
            entity_name,
            pk1_value,
            recipient_type,
            recipient_user_name,
            recipient_party_contact_id,
            rfi_category,
            description,
            continue_other_work_flag,
            rfi_status,
            due_date,
            response_token_hash,
            token_expiry_date
        ) values
            ( p_entity_name,
              p_pk1_value,
              p_recipient_type,
              upper(p_recipient_user_name),
              p_party_contact_id,
              p_rfi_category,
              p_description,
              p_continue_other_work,
              case
                  when p_continue_other_work = 'Y' then
                        'WAITING_FOR_INFORMATION'
                  else
                      'ON_HOLD_PENDING'
              end,
              p_due_date,
              l_hash,
              case
                  when l_hash is not null then
                        cast(nvl(p_due_date,
                                 trunc(sysdate) + 14) + 1 as timestamp)
              end
            )
        returning rfi_id into p_rfi_id;
        -- An internal recipient answers through an APEX action task in My Tasks; an external
        -- party answers through the emailed link (no task: it has no application account).
        if p_recipient_type = 'REQUESTING_DEPARTMENT' then
            l_task_id := xxfnd_task_pkg.create_task('RFI_RESPONSE',
                                                    to_char(p_rfi_id));
            update xxcmp_rfis
            set
                response_task_id = l_task_id
            where
                rfi_id = p_rfi_id;

        end if;

    end create_rfi;

    function rfi_recipient (
        p_rfi_id in number
    ) return varchar2 is
        l_user xxcmp_rfis.recipient_user_name%type;
    begin
        select
            recipient_user_name
        into l_user
        from
            xxcmp_rfis
        where
            rfi_id = p_rfi_id;

        return l_user;
    end rfi_recipient;

    -- A response has arrived: the Compliance team reviews it (RFI_REVIEW action task).
    procedure start_review (
        p_rfi_id in number
    ) is
        l_task_id number;
    begin
        l_task_id := xxfnd_task_pkg.create_task('RFI_REVIEW',
                                                to_char(p_rfi_id));
        update xxcmp_rfis
        set
            review_task_id = l_task_id
        where
            rfi_id = p_rfi_id;

    end start_review;

    procedure respond (
        p_rfi_id        in number,
        p_response_text in clob
    ) is
        l_rfi xxcmp_rfis%rowtype;
    begin
        select
            *
        into l_rfi
        from
            xxcmp_rfis
        where
            rfi_id = p_rfi_id
        for update;

        if l_rfi.recipient_type <> 'REQUESTING_DEPARTMENT'
        or upper(l_rfi.recipient_user_name) <> upper(xxfnd_util_pkg.current_user) then
            raise_application_error(-20502, 'This request for information is not addressed to you.');
        end if;

        if l_rfi.rfi_status not in ( 'WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING' ) then
            raise_application_error(-20503, 'This request for information is closed.');
        end if;

        update xxcmp_rfis
        set
            response_text = p_response_text,
            responded_date = systimestamp
        where
            rfi_id = p_rfi_id;

        xxfnd_task_pkg.complete_open('RFI_RESPONSE',
                                     to_char(p_rfi_id));
        xxfnd_task_pkg.cancel_open('RFI_REVIEW',
                                   to_char(p_rfi_id));   -- a newer answer replaces the older one
        start_review(p_rfi_id);
    end respond;

    function respond_by_token (
        p_token         in varchar2,
        p_response_text in clob
    ) return number is
        l_rfi  xxcmp_rfis%rowtype;
        l_hash varchar2(128) := hash_token(p_token);   -- private function: not callable from SQL
    begin
        -- The caller is an anonymous party (APP_USER nobody); the token is the authorisation,
        -- so row-level data security is bypassed for this call only.
        xxfnd_vpd_pkg.begin_trusted;
        begin
            select
                *
            into l_rfi
            from
                xxcmp_rfis
            where
                response_token_hash = l_hash
            for update;

        exception
            when no_data_found then
                raise_application_error(-20504, 'This link is not valid.');
        end;

        if l_rfi.token_expiry_date < systimestamp
        or l_rfi.rfi_status not in ( 'WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING' ) then
            raise_application_error(-20505, 'This link has expired or the request is closed.');
        end if;
        -- One-time: the hash is cleared once the party has answered.
        update xxcmp_rfis
        set
            response_text = p_response_text,
            responded_date = systimestamp,
            response_token_hash = null,
            token_expiry_date = null
        where
            rfi_id = l_rfi.rfi_id;

        start_review(l_rfi.rfi_id);
        xxfnd_vpd_pkg.end_trusted;
        return l_rfi.rfi_id;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end respond_by_token;

    procedure resolve (
        p_rfi_id in number,
        p_status in varchar2,
        p_notes  in varchar2
    ) is
    begin
        if p_status not in ( 'RESOLVED', 'REJECTED_RETURNED', 'CANCELLED', 'ON_HOLD_INVESTIGATION' ) then
            raise_application_error(-20506, 'Status '
                                            || p_status
                                            || ' cannot be set here.');
        end if;

        update xxcmp_rfis
        set
            rfi_status = p_status,
            resolution_notes = p_notes,
            resolved_date =
                case
                    when p_status in ( 'RESOLVED', 'REJECTED_RETURNED', 'CANCELLED' ) then
                        systimestamp
                end,
            response_token_hash =
                case
                    when p_status in ( 'RESOLVED', 'REJECTED_RETURNED', 'CANCELLED' ) then
                        null
                    else
                        response_token_hash
                end
        where
            rfi_id = p_rfi_id;

        if sql%rowcount = 0 then
            raise_application_error(-20507, 'Request for information '
                                            || p_rfi_id
                                            || ' does not exist.');
        end if;

        if p_status in ( 'RESOLVED', 'REJECTED_RETURNED' ) then
            xxfnd_task_pkg.complete_open('RFI_REVIEW',
                                         to_char(p_rfi_id));
        elsif p_status = 'CANCELLED' then
            xxfnd_task_pkg.cancel_open('RFI_RESPONSE',
                                       to_char(p_rfi_id));
            xxfnd_task_pkg.cancel_open('RFI_REVIEW',
                                       to_char(p_rfi_id));
        end if;

    end resolve;

    procedure send_rfi_email (
        p_rfi_id       in number,
        p_response_url in varchar2 default null
    ) is

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
        select
            *
        into l_rfi
        from
            xxcmp_rfis
        where
            rfi_id = p_rfi_id;

        if l_rfi.recipient_type = 'REQUESTING_DEPARTMENT' then
            select
                email_address,
                full_name
            into
                l_to,
                l_name
            from
                xxfnd_employees
            where
                user_name = upper(l_rfi.recipient_user_name);

            l_template := 'RFI_RAISED_INTERNAL';
        else
            select
                contact_value,
                contact_name
            into
                l_to,
                l_name
            from
                xxcmp_party_contacts
            where
                party_contact_id = l_rfi.recipient_party_contact_id;

            l_template := 'RFI_RAISED_EXTERNAL';
        end if;

        select
            nvl(t.subject, n.subject),
            nvl(t.body_html, n.body_html)
        into
            l_subject,
            l_body
        from
            xxfnd_notification_templates    n
            left join xxfnd_notification_templates_tl t on t.template_code = n.template_code
                                                           and t.language_code = xxfnd_util_pkg.current_lang
        where
            n.template_code = l_template;

        l_json := json_object_t();
        l_json.put('RFI_NUMBER', l_rfi.rfi_number);
        l_json.put('DESCRIPTION',
                   apex_escape.html(l_rfi.description));
        l_json.put('DUE_DATE',
                   to_char(l_rfi.due_date, 'DD-Mon-YYYY'));
        l_json.put('CONTACT_NAME',
                   apex_escape.html(nvl(l_name, 'Sir/Madam')));

        l_json.put('RESPONSE_URL', p_response_url);
        l_tokens := l_json.to_clob;
        l_mail_id := apex_mail.send(
            p_to        => l_to,
            p_from      => apex_app_setting.get_value('MAIL_FROM'),
            p_subj      => dbms_lob.substr(
                  xxfnd_util_pkg.replace_tokens(l_subject, l_tokens),
                  500,
                  1
              ),
            p_body      => to_clob(l_rfi.description),
            p_body_html => xxfnd_util_pkg.replace_tokens(l_body, l_tokens)
        );

    end send_rfi_email;

end xxcmp_kyc_pkg;
/


-- sqlcl_snapshot {"hash":"212a94a6b9df3a49cd9fd6563e389fe198d69210","type":"PACKAGE_BODY","name":"XXCMP_KYC_PKG","schemaName":"XXCUS","sxml":""}