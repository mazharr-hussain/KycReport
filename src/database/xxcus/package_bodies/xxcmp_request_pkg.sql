create or replace package body xxcus.xxcmp_request_pkg as

    -- Numeric KYC parameter maintained by administrators (lookup KYC_PARAMETER, value in TAG).
    function param (
        p_code    in varchar2,
        p_default in number
    ) return number is
        l_value number;
    begin
        select
            max(to_number(tag default null on conversion error))
        into l_value
        from
            xxfnd_lookup_values
        where
                lookup_type = 'KYC_PARAMETER'
            and lookup_code = p_code
            and enabled_flag = 'Y';

        return nvl(l_value, p_default);
    end param;

    function questionnaire_for (
        p_party_type in varchar2
    ) return varchar2 is
    begin
        return
            case p_party_type
                when 'PERSON' then
                    'INDIVIDUAL'
                else
                    'CORPORATE'
            end;
    end questionnaire_for;

    procedure add_answer_rows (
        p_request_id    in number,
        p_case_id       in number,
        p_questionnaire in varchar2,
        p_respondent    in varchar2
    ) is
    begin
        insert into xxcmp_request_answers (
            request_id,
            case_id,
            respondent_type,
            question_id
        )
            select
                p_request_id,
                p_case_id,
                p_respondent,
                q.question_id
            from
                xxcmp_questions q
            where
                    q.questionnaire_code = p_questionnaire
                and q.enabled_flag = 'Y'
                and not exists (
                    select
                        1
                    from
                        xxcmp_request_answers a
                    where
                            a.request_id = p_request_id
                        and a.respondent_type = p_respondent
                        and a.question_id = q.question_id
                );

    end add_answer_rows;

    function create_request (
        p_party_type            in varchar2,
        p_party_name            in varchar2,
        p_registration_number   in varchar2 default null,
        p_jurisdiction          in varchar2 default null,
        p_entity_type           in varchar2 default null,
        p_date_of_birth         in date default null,
        p_nationality           in varchar2 default null,
        p_requesting_department in varchar2 default null,
        p_justification         in varchar2 default null,
        p_request_type          in varchar2 default 'NEW_ONBOARDING',
        p_trigger_source        in varchar2 default 'MANUAL',
        p_parent_request_id     in number default null,
        p_parent_case_id        in number default null,
        p_party_id              in number default null
    ) return number is

        l_id  number;
        l_qnr varchar2(30) :=
            case
                when p_request_type = 'NEW_ONBOARDING' then
                    questionnaire_for(p_party_type)
            end;
    begin
        insert into xxcmp_requests (
            request_number,
            request_type,
            trigger_source,
            parent_request_id,
            parent_case_id,
            party_id,
            party_type,
            party_name,
            registration_number,
            jurisdiction,
            entity_type,
            date_of_birth,
            nationality,
            requesting_department,
            requester_user_name,
            questionnaire_code,
            justification
        ) values
            ( 'REQ-'
              || lpad(xxcmp_request_number_s.nextval, 6, '0'),
              p_request_type,
              p_trigger_source,
              p_parent_request_id,
              p_parent_case_id,
              p_party_id,
              p_party_type,
              p_party_name,
              p_registration_number,
              p_jurisdiction,
              p_entity_type,
              p_date_of_birth,
              p_nationality,
              p_requesting_department,
              xxfnd_util_pkg.current_user,
              l_qnr,
              p_justification )
        returning request_id into l_id;

        if l_qnr is not null then
            add_answer_rows(l_id, null, l_qnr, 'REQUESTER');
        end if;

        return l_id;
    end create_request;

    function norm_id (
        p_value in varchar2
    ) return varchar2 is
    begin
        return upper(regexp_replace(p_value, '[^[:alnum:]]', ''));
    end norm_id;

    function counterparty_error (
        p_party_selection     in varchar2,
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
        p_draft               in varchar2 default 'N'
    ) return varchar2 is
    begin
        if p_party_selection = 'EXISTING' then
            return
                case
                    when p_party_id is null then
                        'Choose the existing counterparty.'
                end;
        elsif p_party_type not in ( 'ORGANIZATION', 'PERSON' )
              or p_party_type is null then
            return 'Choose the counterparty type.';
        elsif trim(p_party_name) is null then
            return 'Enter the name.';
        elsif p_draft = 'Y' then
            return null;
        elsif trim(p_jurisdiction) is null then
            return 'Choose the country.';
        elsif p_party_type = 'ORGANIZATION' then
            if trim(p_registration_number) is null then
                return 'Enter the registration number of the organisation.';
            elsif trim(p_entity_type) is null then
                return 'Choose the entity type of the organisation.';
            elsif p_incorporation_date > trunc(sysdate) then
                return 'The date of incorporation cannot be in the future.';
            end if;
        else
            if p_date_of_birth is null then
                return 'Enter the date of birth.';
            elsif p_date_of_birth > trunc(sysdate) then
                return 'The date of birth cannot be in the future.';
            elsif trim(p_nationality) is null then
                return 'Choose the nationality.';
            elsif p_id_type is null
                  or trim(p_id_number) is null then
                return 'Enter the identity document type and number.';
            end if;
        end if;

        return null;
    end counterparty_error;

    procedure save_counterparty (
        p_request_id            in out number,
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
        p_draft                 in varchar2 default 'N'
    ) is

        l_error varchar2(4000) := counterparty_error(p_party_selection, p_party_id, p_party_type, p_party_name, p_registration_number
        ,
                                                     p_entity_type, p_incorporation_date, p_id_type, p_id_number, p_jurisdiction,
                                                     p_date_of_birth, p_nationality, p_draft);
        l_new   xxcmp_requests%rowtype;
        l_old   xxcmp_requests%rowtype;
        l_party xxcmp_parties%rowtype;
        l_org   boolean;
    begin
        if l_error is not null then
            raise_application_error(-20611, l_error);
        end if;
        -- the values to keep: the chosen party's, or what was typed (only what applies to the type)
        if p_party_selection = 'EXISTING' then
            xxfnd_vpd_pkg.begin_trusted;    -- requesters cannot read the party master
            begin
                select
                    *
                into l_party
                from
                    xxcmp_parties
                where
                        party_id = p_party_id
                    and enabled_flag = 'Y';

            exception
                when no_data_found then
                    xxfnd_vpd_pkg.end_trusted;
                    raise_application_error(-20618, 'The chosen counterparty does not exist or is disabled.');
            end;

            xxfnd_vpd_pkg.end_trusted;
            l_new.party_selection := 'EXISTING';
            l_new.party_id := l_party.party_id;
            l_new.party_type := l_party.party_type;
            l_new.party_name := l_party.party_name;
            l_new.registration_number := l_party.registration_number;
            l_new.entity_type := l_party.entity_type;
            l_new.incorporation_date := l_party.incorporation_date;
            l_new.id_type := l_party.id_type;
            l_new.id_number := l_party.id_number;
            l_new.jurisdiction := l_party.jurisdiction;
            l_new.date_of_birth := l_party.date_of_birth;
            l_new.nationality := l_party.nationality;
            l_new.match_status := 'SELECTED';
            l_new.match_ack_flag := 'N';
        else
            l_org := p_party_type = 'ORGANIZATION';
            l_new.party_selection := 'NEW';
            l_new.party_type := p_party_type;
            l_new.party_name := trim(p_party_name);
            l_new.jurisdiction := p_jurisdiction;
            if l_org then
                l_new.registration_number := trim(p_registration_number);
                l_new.entity_type := p_entity_type;
                l_new.incorporation_date := p_incorporation_date;
            else
                l_new.date_of_birth := p_date_of_birth;
                l_new.nationality := p_nationality;
                l_new.id_type := p_id_type;
                l_new.id_number := trim(p_id_number);
            end if;

            l_new.match_ack_flag :=
                case
                    when p_match_ack = 'Y' then
                        'Y'
                    else
                        'N'
                end;
        end if;

        if p_request_id is null then
            p_request_id := create_request(
                p_party_type            => l_new.party_type,
                p_party_name            => l_new.party_name,
                p_requesting_department => p_requesting_department,
                p_justification         => p_justification
            );
        end if;

        select
            *
        into l_old
        from
            xxcmp_requests
        where
            request_id = p_request_id
        for update;

        if l_old.request_status <> 'DRAFT' then
            raise_application_error(-20612, 'Request '
                                            || l_old.request_number
                                            || ' has been submitted and can no longer be changed.');
        end if;

        update xxcmp_requests
        set
            party_selection = l_new.party_selection,
            party_id = l_new.party_id,
            party_type = l_new.party_type,
            party_name = l_new.party_name,
            registration_number = l_new.registration_number,
            entity_type = l_new.entity_type,
            incorporation_date = l_new.incorporation_date,
            id_type = l_new.id_type,
            id_number = l_new.id_number,
            jurisdiction = l_new.jurisdiction,
            date_of_birth = l_new.date_of_birth,
            nationality = l_new.nationality,
            match_ack_flag = l_new.match_ack_flag,
            match_status = l_new.match_status,
            requesting_department = p_requesting_department,
            justification = p_justification,
            questionnaire_code = questionnaire_for(l_new.party_type)
        where
            request_id = p_request_id;
        -- another type answers another questionnaire
        if nvl(l_old.questionnaire_code, '#') <> questionnaire_for(l_new.party_type) then
            delete from xxcmp_request_answers
            where
                    request_id = p_request_id
                and respondent_type = 'REQUESTER';

            add_answer_rows(p_request_id,
                            null,
                            questionnaire_for(l_new.party_type),
                            'REQUESTER');
        end if;

    end save_counterparty;

    function party_directory_json (
        p_party_type in varchar2
    ) return clob is
        l_json clob;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select
            json_arrayagg(
                json_object(
                    'party_id' value party_id,
                            'party_number' value party_number,
                            'party_name' value party_name,
                            'country' value xxfnd_util_pkg.lookup_meaning('JURISDICTION', jurisdiction)
                )
            order by
                party_name
            returning clob)
        into l_json
        from
            xxcmp_parties
        where
                party_type = p_party_type
            and enabled_flag = 'Y';

        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_json, '[]');
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end party_directory_json;

    function party_candidates_json (
        p_party_type          in varchar2,
        p_party_name          in varchar2,
        p_registration_number in varchar2,
        p_id_number           in varchar2,
        p_date                in date,
        p_country             in varchar2
    ) return clob is

        l_json clob;
        l_id   varchar2(100) := norm_id(
            case p_party_type
                when 'ORGANIZATION' then
                    p_registration_number
                else
                    p_id_number
            end
        );
    begin
        if
            trim(p_party_name) is null
            and l_id is null
        then
            return '[]';
        end if;
        xxfnd_vpd_pkg.begin_trusted;    -- the whole party master, but only safe columns leave this function
        select
            json_arrayagg(
                json_object(
                    'party_id' value party_id,
                    'party_number' value party_number,
                    'party_name' value party_name,
                    'country' value country,
                    'score' value score,
                            'reasons' value reasons
                )
            order by
                score desc,
                party_name
            returning clob)
        into l_json
        from
            (
                select
                    m.*,
                    case
                        when id_hit = 'Y' then
                            100
                        else
                            least(99,
                                  round(similarity * 0.7 +
                                case
                                    when date_hit = 'Y' then
                                        20
                                    else
                                        0
                                end
                                        +
                                case
                                    when country_hit = 'Y' then
                                        10
                                    else
                                        0
                                end
                            ))
                    end         as score,
                    rtrim(
                        case
                            when id_hit = 'Y' then
                                    case p_party_type
                                        when 'ORGANIZATION' then
                                            'Same registration number; '
                                        else
                                            'Same identity document number; '
                                    end
                        end
                        ||
                        case
                            when similarity >= 70 then
                                'Name '
                                || round(similarity)
                                || '% similar; '
                        end
                        ||
                        case
                            when date_hit = 'Y' then
                                    case p_party_type
                                        when 'ORGANIZATION' then
                                            'Same date of incorporation; '
                                        else
                                            'Same date of birth; '
                                    end
                        end
                        ||
                        case
                            when country_hit = 'Y' then
                                'Same country; '
                        end,
                        '; ') as reasons
                from
                    (
                        select
                            p.party_id,
                            p.party_number,
                            p.party_name,
                            xxfnd_util_pkg.lookup_meaning('JURISDICTION', p.jurisdiction) as country,
                            case
                                when l_id is not null
                                     -- same normalisation as NORM_ID (private functions cannot be used in SQL)
                                     and upper(regexp_replace(
                                    case p.party_type
                                        when 'ORGANIZATION' then
                                            p.registration_number
                                        else
                                            p.id_number
                                    end, '[^[:alnum:]]', '')) = l_id then
                                    'Y'
                                else
                                    'N'
                            end                                                           as id_hit,
                            case
                                when trim(p_party_name) is not null then
                                    xxcmp_kyc_pkg.name_similarity(p.party_name, p_party_name)
                                else
                                    0
                            end                                                           as similarity,
                            case
                                when p_date is not null
                                     and p_date = case p.party_type
                                    when 'ORGANIZATION' then
                                        p.incorporation_date
                                    else
                                        p.date_of_birth
                                                  end then
                                    'Y'
                                else
                                    'N'
                            end                                                           as date_hit,
                            case
                                when p_country is not null
                                     and p.jurisdiction = p_country then
                                    'Y'
                                else
                                    'N'
                            end                                                           as country_hit
                        from
                            xxcmp_parties p
                        where
                                p.party_type = p_party_type
                            and p.enabled_flag = 'Y'
                    ) m
                where
                    id_hit = 'Y'
                    or similarity >= 85
                    or ( similarity >= 70
                         and date_hit = 'Y' )
                order by
                    score desc
                fetch first 10 rows only
            );

        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_json, '[]');
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end party_candidates_json;

    function party_candidate_count (
        p_party_type          in varchar2,
        p_party_name          in varchar2,
        p_registration_number in varchar2,
        p_id_number           in varchar2,
        p_date                in date,
        p_country             in varchar2
    ) return number is
    begin
        return json_array_t.parse(party_candidates_json(p_party_type, p_party_name, p_registration_number, p_id_number, p_date,
                                                        p_country)).get_size;
    end party_candidate_count;

    function request_candidates_json (
        p_request_id in number
    ) return clob is
        l_req xxcmp_requests%rowtype;
    begin
        select
            *
        into l_req
        from
            xxcmp_requests
        where
            request_id = p_request_id;

        return party_candidates_json(l_req.party_type, l_req.party_name, l_req.registration_number, l_req.id_number,
                                     case l_req.party_type
                                         when 'ORGANIZATION' then
                                             l_req.incorporation_date
                                         else
                                             l_req.date_of_birth
                                     end,
                                     l_req.jurisdiction);

    end request_candidates_json;

    function match_pending (
        p_request_id in number
    ) return varchar2 is
        l_status xxcmp_requests.match_status%type;
    begin
        select
            max(match_status)
        into l_status
        from
            xxcmp_requests
        where
            request_id = p_request_id;

        return
            case
                when l_status = 'PENDING' then
                    'Y'
                else
                    'N'
            end;
    end match_pending;

    function questionnaire_html (
        p_request_id in number,
        p_respondent in varchar2 default 'REQUESTER'
    ) return clob is

        l_html    clob;
        l_section varchar2(240) := chr(0);
        l_lang    varchar2(10) := xxfnd_util_pkg.current_lang;
        l_id      varchar2(100);

        procedure add (
            p_text in varchar2
        ) is
        begin
            dbms_lob.writeappend(l_html,
                                 length(p_text),
                                 p_text);
        end add;

    begin
        dbms_lob.createtemporary(l_html, true);
        add('<div class="kyc-questionnaire">');
        for q in (
            select
                a.question_id,
                a.answer_option_id,
                a.answer_text,
                qu.answer_type,
                qu.required_flag,
                nvl(tl.question_text, qu.question_text) as question_text,
                nvl(
                    nvl(tl.section_name, qu.section_name),
                    'General'
                )                                       as section_name
            from
                     xxcmp_request_answers a
                join xxcmp_questions    qu on qu.question_id = a.question_id
                left join xxcmp_questions_tl tl on tl.question_id = qu.question_id
                                                   and tl.language_code = l_lang
            where
                    a.request_id = p_request_id
                and a.respondent_type = p_respondent
                   -- a section's questions stay together, in the order of its first question
            order by
                min(qu.display_sequence)
                over(partition by nvl(
                    nvl(tl.section_name, qu.section_name),
                    'General'
                )),
                qu.display_sequence,
                qu.question_id
        ) loop
            if q.section_name <> l_section then
                if l_section <> chr(0) then
                    add('</div>');
                end if;
                l_section := q.section_name;
                add('<div class="kyc-section"><h3 class="kyc-section-title">'
                    || apex_escape.html(q.section_name) || '</h3>');
            end if;

            l_id := 'kycq_' || q.question_id;
            add('<fieldset class="kyc-q" data-kyc-q="'
                || q.question_id
                || '" data-kyc-type="'
                || q.answer_type
                || '">'
                || '<legend class="kyc-q-text">'
                || apex_escape.html(q.question_text)
                ||
                case
                    when q.required_flag = 'Y' then
                        ' <span class="kyc-q-required" title="Required">*</span>'
                end
                || '</legend>');

            if q.answer_type in ( 'YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT' ) then
                add('<div class="kyc-q-options" role="radiogroup">');
                for o in (
                    select
                        answer_option_id,
                        answer_label
                    from
                        xxcmp_answer_options
                    where
                            question_id = q.question_id
                        and approval_status = 'APPROVED'
                        and enabled_flag = 'Y'
                    order by
                        display_sequence,
                        answer_option_id
                ) loop
                    add('<label class="kyc-q-option"><input type="radio" name="'
                        || l_id
                        || '" value="'
                        || o.answer_option_id
                        || '"'
                        ||
                        case
                            when o.answer_option_id = q.answer_option_id then
                                ' checked'
                        end
                        || '> <span>'
                        || apex_escape.html(o.answer_label) || '</span></label>');
                end loop;

                add('</div>');
            elsif q.answer_type = 'TEXT' then
                add('<textarea class="textarea apex-item-textarea kyc-q-input" rows="3" maxlength="4000" aria-label="'
                    || apex_escape.html_attribute(q.question_text)
                    || '">'
                    || apex_escape.html(q.answer_text) || '</textarea>');
            else
                add('<input class="text_field apex-item-text kyc-q-input" type="'
                    ||
                    case q.answer_type
                        when 'DATE' then
                            'date'
                        else
                            'text" inputmode="decimal'
                    end
                    || '" value="'
                    || apex_escape.html_attribute(q.answer_text)
                    || '" aria-label="'
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

    function answers_error (
        p_request_id in number,
        p_answers    in clob
    ) return varchar2 is
        l_missing varchar2(4000);
    begin
        select
            listagg(qu.question_text, '; ') within group(
            order by
                qu.display_sequence
            )
        into l_missing
        from
                 xxcmp_request_answers a
            join xxcmp_questions qu on qu.question_id = a.question_id
        where
                a.request_id = p_request_id
            and a.respondent_type = 'REQUESTER'
            and qu.required_flag = 'Y'
            and not exists (
                select
                    1
                from
                        json_table ( nvl(p_answers, '[]'), '$[*]'
                            columns (
                                q number path '$.q',
                                o number path '$.o',
                                t varchar2 ( 4000 ) path '$.t'
                            )
                        )
                    j
                where
                        j.q = a.question_id
                    and ( j.o is not null
                          or trim(j.t) is not null )
            );

        return
            case
                when l_missing is not null then
                    'Answer the required questions: ' || l_missing
            end;
    end answers_error;

    procedure save_answers (
        p_request_id in number,
        p_answers    in clob
    ) is

        l_status xxcmp_requests.request_status%type;
        l_type   xxcmp_questions.answer_type%type;
        l_option number;
        l_text   varchar2(4000);
    begin
        select
            request_status
        into l_status
        from
            xxcmp_requests
        where
            request_id = p_request_id;

        if l_status <> 'DRAFT' then
            raise_application_error(-20613, 'The request has been submitted; its answers can no longer be changed.');
        end if;
        for j in (
            select
                q,
                o,
                t
            from
                json_table ( nvl(p_answers, '[]'), '$[*]'
                    columns (
                        q number path '$.q',
                        o number path '$.o',
                        t varchar2 ( 4000 ) path '$.t'
                    )
                )
        ) loop
            begin
                select
                    qu.answer_type
                into l_type
                from
                         xxcmp_request_answers a
                    join xxcmp_questions qu on qu.question_id = a.question_id
                where
                        a.request_id = p_request_id
                    and a.respondent_type = 'REQUESTER'
                    and a.question_id = j.q;

            exception
                when no_data_found then
                    raise_application_error(-20614, 'Question '
                                                    || j.q
                                                    || ' does not belong to this request.');
            end;

            l_option := null;
            l_text := null;
            if l_type in ( 'YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT' ) then
                if j.o is not null then
                    select
                        max(answer_option_id)
                    into l_option
                    from
                        xxcmp_answer_options
                    where
                            answer_option_id = j.o
                        and question_id = j.q
                        and approval_status = 'APPROVED'
                        and enabled_flag = 'Y';

                    if l_option is null then
                        raise_application_error(-20615, 'Answer '
                                                        || j.o
                                                        || ' is not an option of question '
                                                        || j.q
                                                        || '.');

                    end if;

                end if;
            elsif
                l_type = 'NUMBER'
                and trim(j.t) is not null
                and validate_conversion ( trim(j.t) as
                    number
                ) = 0
            then
                raise_application_error(-20616, 'Enter a number for: ' || j.t);
            else
                l_text := trim(j.t);
            end if;

            update xxcmp_request_answers
            set
                answer_option_id = l_option,
                answer_text =
                    case
                        when l_type in ( 'YES_NO', 'SINGLE_SELECT', 'MULTI_SELECT' ) then
                            answer_text
                        else
                            l_text
                    end
            where
                    request_id = p_request_id
                and respondent_type = 'REQUESTER'
                and question_id = j.q;

        end loop;

    end save_answers;

    function submit_error (
        p_request_id in number
    ) return varchar2 is
        l_req     xxcmp_requests%rowtype;
        l_missing pls_integer;
    begin
        select
            *
        into l_req
        from
            xxcmp_requests
        where
            request_id = p_request_id;

        if l_req.request_status <> 'DRAFT' then
            return 'This request has already been submitted.';
        end if;
        select
            count(*)
        into l_missing
        from
                 xxcmp_request_answers a
            join xxcmp_questions q on q.question_id = a.question_id
        where
                a.request_id = p_request_id
            and a.respondent_type = 'REQUESTER'
            and q.required_flag = 'Y'
            and a.answer_option_id is null
            and a.answer_text is null;

        if l_missing > 0 then
            return l_missing || ' required question(s) are not answered.';
        end if;
        return null;
    end submit_error;

    procedure submit (
        p_request_id in number
    ) is
        l_error varchar2(4000) := submit_error(p_request_id);
        l_wf    number;
    begin
        if l_error is not null then
            raise_application_error(-20601, l_error);
        end if;
        update xxcmp_requests
        set
            request_status = 'SUBMITTED',
            submitted_date = systimestamp
        where
            request_id = p_request_id;

        l_wf := apex_workflow.start_workflow(
            p_application_id => v('APP_ID'),
            p_static_id      => 'KYC_REQUEST',
            p_detail_pk      => to_char(p_request_id)
        );

        update xxcmp_requests
        set
            workflow_id = l_wf
        where
            request_id = p_request_id;

    end submit;

    function new_party (
        p_req in xxcmp_requests%rowtype
    ) return number is
        l_id number;
    begin
        insert into xxcmp_parties (
            party_type,
            party_name,
            registration_number,
            jurisdiction,
            entity_type,
            incorporation_date,
            date_of_birth,
            nationality,
            id_type,
            id_number,
            data_provenance
        ) values
            ( p_req.party_type,
              p_req.party_name,
              p_req.registration_number,
              p_req.jurisdiction,
              p_req.entity_type,
              p_req.incorporation_date,
              p_req.date_of_birth,
              p_req.nationality,
              p_req.id_type,
              p_req.id_number,
              'SELF_DECLARED' )
        returning party_id into l_id;

        return l_id;
    end new_party;

    -- The request's party: the one the requester chose; else a new party when nothing resembles it; else
    -- Compliance decides (PENDING) - a new counterparty is never linked to an existing party automatically.
    procedure link_party (
        p_req in out xxcmp_requests%rowtype
    ) is
    begin
        if p_req.party_id is not null then
            p_req.match_status := nvl(p_req.match_status, 'SELECTED');
        elsif party_candidate_count(p_req.party_type, p_req.party_name, p_req.registration_number, p_req.id_number,
                                    case p_req.party_type
                                        when 'ORGANIZATION' then
                                            p_req.incorporation_date
                                        else
                                            p_req.date_of_birth
                                    end,
                                    p_req.jurisdiction) > 0 then
            p_req.match_status := 'PENDING';
        else
            p_req.party_id := new_party(p_req);
            p_req.match_status := 'NEW';
        end if;

        update xxcmp_requests
        set
            party_id = p_req.party_id,
            match_status = p_req.match_status
        where
            request_id = p_req.request_id;

    end link_party;

    procedure resolve_match (
        p_request_id in number,
        p_party_id   in number default null,
        p_note       in varchar2 default null
    ) is
        l_req   xxcmp_requests%rowtype;
        l_party xxcmp_parties%rowtype;
    begin
        if not xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') then
            raise_application_error(-20619, 'Only Compliance can decide whether a counterparty is an existing party.');
        end if;

        xxfnd_vpd_pkg.begin_trusted;
        select
            *
        into l_req
        from
            xxcmp_requests
        where
            request_id = p_request_id
        for update;

        if nvl(l_req.match_status, '#') <> 'PENDING' then
            raise_application_error(-20620, 'The counterparty of request '
                                            || l_req.request_number
                                            || ' has already been decided.');
        end if;

        if p_party_id is not null then
            select
                *
            into l_party
            from
                xxcmp_parties
            where
                party_id = p_party_id
            for update;

            if l_party.party_type <> l_req.party_type then
                raise_application_error(-20621, 'An organisation cannot be merged into an individual, or the reverse.');
            end if;
            -- merge: the party keeps its data; empty fields are completed from the request
            update xxcmp_parties
            set
                registration_number =
                    case
                        when party_type = 'ORGANIZATION' then
                            nvl(registration_number, l_req.registration_number)
                    end,
                entity_type =
                    case
                        when party_type = 'ORGANIZATION' then
                            nvl(entity_type, l_req.entity_type)
                    end,
                incorporation_date =
                    case
                        when party_type = 'ORGANIZATION' then
                            nvl(incorporation_date, l_req.incorporation_date)
                    end,
                date_of_birth =
                    case
                        when party_type = 'PERSON' then
                            nvl(date_of_birth, l_req.date_of_birth)
                    end,
                nationality =
                    case
                        when party_type = 'PERSON' then
                            nvl(nationality, l_req.nationality)
                    end,
                id_type =
                    case
                        when party_type = 'PERSON' then
                            nvl(id_type, l_req.id_type)
                    end,
                id_number =
                    case
                        when party_type = 'PERSON' then
                            nvl(id_number, l_req.id_number)
                    end,
                jurisdiction = nvl(jurisdiction, l_req.jurisdiction)
            where
                party_id = p_party_id;

            l_req.party_id := p_party_id;
            l_req.match_status := 'MERGED';
        else
            l_req.party_id := new_party(l_req);
            l_req.match_status := 'CONFIRMED_NEW';
        end if;

        update xxcmp_requests
        set
            party_id = l_req.party_id,
            match_status = l_req.match_status,
            match_note = p_note,
            match_resolved_by = xxfnd_util_pkg.current_user,
            match_resolved_date = systimestamp
        where
            request_id = p_request_id;
        -- the workflow waits on the Counterparty Match task: completing it moves on to the document checklist
        xxfnd_task_pkg.complete_open('COUNTERPARTY_MATCH',
                                     to_char(p_request_id));
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end resolve_match;

    procedure evaluate (
        p_request_id in number
    ) is

        l_req      xxcmp_requests%rowtype;
        l_score    number;
        l_critical pls_integer;
        l_waiver   pls_integer;
        l_low      number;
        l_outcome  varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select
            *
        into l_req
        from
            xxcmp_requests
        where
            request_id = p_request_id
        for update;

        link_party(l_req);
        if l_req.request_type <> 'NEW_ONBOARDING'
        or l_req.questionnaire_code is null then
            l_outcome := 'ASSIGNED';                          -- reviews always go to Compliance
        else
            update xxcmp_request_answers a
            set
                risk_points = (
                    select
                        o.risk_points
                    from
                        xxcmp_answer_options o
                    where
                        o.answer_option_id = a.answer_option_id
                )
            where
                    a.request_id = p_request_id
                and a.respondent_type = 'REQUESTER';

            select
                nvl(
                    sum(a.risk_points),
                    0
                ),
                count(
                    case
                        when o.critical_flag = 'Y' then
                            1
                    end
                ),
                count(
                    case
                        when q.gate_question_flag = 'Y'
                             and o.waiver_qualifying_flag = 'Y' then
                            1
                    end
                )
            into
                l_score,
                l_critical,
                l_waiver
            from
                     xxcmp_request_answers a
                join xxcmp_questions      q on q.question_id = a.question_id
                left join xxcmp_answer_options o on o.answer_option_id = a.answer_option_id
            where
                    a.request_id = p_request_id
                and a.respondent_type = 'REQUESTER';

            select
                low_risk_max_score
            into l_low
            from
                xxcmp_questionnaires
            where
                questionnaire_code = l_req.questionnaire_code;

            l_outcome :=
                case
                    when l_critical > 0 then
                        'ASSIGNED'
                    when l_waiver > 0   then
                        'NOT_REQUIRED'
                    when l_low is not null
                         and l_score <= l_low then
                        'AUTO_APPROVED'
                    else
                        'ASSIGNED'
                end;

            update xxcmp_requests
            set
                intake_score = l_score,
                intake_critical_flag =
                    case
                        when l_critical > 0 then
                            'Y'
                        else
                            'N'
                    end
            where
                request_id = p_request_id;

        end if;

        if l_req.match_status = 'PENDING' then
            l_outcome := 'ASSIGNED';     -- possibly an existing party: Compliance decides
        end if;
        update xxcmp_requests
        set
            intake_outcome = l_outcome,
            request_status =
                case
                    when l_outcome = 'ASSIGNED' then
                        'IN_PROGRESS'
                    else
                        request_status
                end
        where
            request_id = p_request_id;

        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end evaluate;

    function outcome (
        p_request_id in number
    ) return varchar2 is
        l_outcome varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select
            intake_outcome
        into l_outcome
        from
            xxcmp_requests
        where
            request_id = p_request_id;

        xxfnd_vpd_pkg.end_trusted;
        return l_outcome;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end outcome;

    procedure close_without_case (
        p_request_id in number
    ) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests
        set
            request_status = 'COMPLETED',
            completed_date = systimestamp
        where
            request_id = p_request_id;

        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end close_without_case;

    procedure create_case (
        p_request_id in number
    ) is
        l_case number;
    begin
        if match_pending(p_request_id) = 'Y' then
            raise_application_error(-20622, 'The counterparty of the request is not decided yet: no case can be opened.');
        end if;

        l_case := xxcmp_case_pkg.create_case(p_request_id);
    end create_case;

    procedure reject (
        p_request_id in number
    ) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_requests
        set
            request_status = 'REJECTED',
            completed_date = systimestamp
        where
            request_id = p_request_id;

        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end reject;

    function stage (
        p_request_id in number
    ) return varchar2 is
        l_status  varchar2(30);
        l_outcome varchar2(30);
    begin
        select
            request_status,
            intake_outcome
        into
            l_status,
            l_outcome
        from
            xxcmp_requests
        where
            request_id = p_request_id;

        return
            case
                when l_status = 'DRAFT'     then
                    'Draft'
                when l_status = 'SUBMITTED'
                     and l_outcome is null then
                    'Processing'
                when l_status in ( 'SUBMITTED', 'IN_PROGRESS' ) then
                    'In Progress'
                when l_status = 'COMPLETED'
                     and l_outcome = 'NOT_REQUIRED' then
                    'Completed - KYC not required'
                when l_status = 'COMPLETED'
                     and l_outcome = 'AUTO_APPROVED' then
                    'Completed - approved'
                when l_status = 'COMPLETED' then
                    'Completed'
                when l_status = 'REJECTED'  then
                    'Rejected'
                else
                    initcap(l_status)
            end;

    end stage;

    function start_review (
        p_case_id        in number,
        p_request_type   in varchar2,
        p_trigger_source in varchar2,
        p_justification  in varchar2
    ) return number is
        l_id    number;
        l_party xxcmp_parties%rowtype;
        l_case  xxcmp_cases%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select
            *
        into l_case
        from
            xxcmp_cases
        where
            case_id = p_case_id;

        select
            *
        into l_party
        from
            xxcmp_parties
        where
            party_id = l_case.party_id;

        l_id := create_request(
            p_party_type          => l_party.party_type,
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
            p_party_id            => l_case.party_id
        );

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


-- sqlcl_snapshot {"hash":"e9688f8b9d43fb0e0147088625b0b479f8374e56","type":"PACKAGE_BODY","name":"XXCMP_REQUEST_PKG","schemaName":"XXCUS","sxml":""}