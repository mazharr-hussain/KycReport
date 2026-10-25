
create or replace package body xxcmp_party_pkg as

    -- relationship types that are ownership (Ownership % required)
    c_ownership_types constant varchar2(200) := ':SHAREHOLDER:BENEFICIAL_OWNER:PARENT_COMPANY:';

    -- release 74: name similarity, party directory and candidates (from the request and KYC rules packages)
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

    function party_directory_json(p_party_type in varchar2) return clob is
        l_json clob;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select json_arrayagg(json_object('party_id' value party_id, 'party_number' value party_number,
                                         'party_name' value party_name,
                                         'country' value xxfnd_lookup_pkg.lookup_meaning('JURISDICTION', jurisdiction))
                             order by party_name returning clob)
          into l_json
          from xxcmp_parties
         where (party_type = p_party_type or p_party_type is null) and enabled_flag = 'Y' and party_status = 'APPROVED';
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
                                   p_date                in date,
                                   p_country             in varchar2,
                                   p_exclude_party_id    in number default null) return clob is
        l_json clob;
        l_id   varchar2(100) := upper(regexp_replace(p_registration_number, '[^[:alnum:]]', ''));
    begin
        if trim(p_party_name) is null and l_id is null then
            return '[]';
        end if;
        xxfnd_vpd_pkg.begin_trusted;    -- the whole party master, but only safe columns leave this function
        select json_arrayagg(json_object('party_id' value party_id, 'party_number' value party_number,
                                         'registration_type' value registration_type,
                                         'registration_number' value registration_number,
                                         'party_name' value party_name, 'country' value country,
                                         'score' value score, 'reg_match' value reg_match, 'reasons' value reasons,
                                         'exact' value case when id_hit = 'Y' and country_hit = 'Y' then 'Y' else 'N' end,
                                         'status' value status)
                             order by score desc, party_name returning clob)
          into l_json
          from (select m.*,
                       case when id_hit = 'Y' and country_hit = 'Y' then 100
                            when id_hit = 'Y' then 90
                            else least(89, round(similarity * 0.7 + case when date_hit = 'Y' then 20 else 0 end
                                                                + case when country_hit = 'Y' then 10 else 0 end)) end as score,
                       case when l_id is not null and party_id_number is not null
                            then round(utl_match.edit_distance_similarity(party_id_number, l_id)) end as reg_match,
                       rtrim(case when id_hit = 'Y' then 'Same ' || lower(field_label(p_party_type, 'REGISTRATION_NUMBER')) || '; ' end
                             || case when similarity >= 70 then 'Name ' || round(similarity) || '% similar; ' end
                             || case when date_hit = 'Y' then 'Same ' || lower(field_label(p_party_type, 'INCORPORATION_DATE')) || '; ' end
                             || case when country_hit = 'Y' then 'Same ' || lower(field_label(p_party_type, 'JURISDICTION')) || '; ' end,
                             '; ') as reasons
                  from (select p.party_id, p.party_number, p.party_name, p.registration_number,
                               xxfnd_lookup_pkg.lookup_meaning(registration_lookup(p.party_type),
                                                             p.registration_type) as registration_type,
                               xxfnd_lookup_pkg.lookup_meaning('PARTY_STATUS', p.party_status) as status,
                               upper(regexp_replace(p.registration_number, '[^[:alnum:]]', '')) as party_id_number,
                               xxfnd_lookup_pkg.lookup_meaning('JURISDICTION', p.jurisdiction) as country,
                               case when l_id is not null
                                     and upper(regexp_replace(p.registration_number, '[^[:alnum:]]', '')) = l_id
                                    then 'Y' else 'N' end as id_hit,
                               case when trim(p_party_name) is not null
                                    then name_similarity(p.party_name, p_party_name) else 0 end as similarity,
                               case when p_date is not null and p_date = p.incorporation_date then 'Y' else 'N' end as date_hit,
                               case when p_country is not null and p.jurisdiction = p_country then 'Y' else 'N' end as country_hit
                          from xxcmp_parties p
                         where p.party_type = p_party_type
                           and p.enabled_flag = 'Y'
                           and p.party_status not in ('REJECTED', 'CANCELLED')
                           and p.party_id <> nvl(p_exclude_party_id, -1)) m
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

    -- release 90: private (PARTY_ERROR below)
    function party_candidate_count(p_party_type          in varchar2,
                                   p_party_name          in varchar2,
                                   p_registration_number in varchar2,
                                   p_date                in date,
                                   p_country             in varchar2,
                                   p_exclude_party_id    in number default null) return number is
    begin
        return json_array_t.parse(party_candidates_json(p_party_type, p_party_name, p_registration_number,
                                                        p_date, p_country, p_exclude_party_id)).get_size;
    end party_candidate_count;


    function field_label(p_party_type in varchar2, p_field in varchar2) return varchar2 is
        l_person boolean := p_party_type = 'PERSON';
    begin
        return case p_field
                   when 'JURISDICTION'        then case when l_person then 'Nationality'   else 'Country' end
                   when 'REGISTRATION_NUMBER' then case when l_person then 'ID Number'     else 'Registration No.' end
                   when 'ENTITY_TYPE'         then 'Entity Type'
                   when 'REGISTRATION_TYPE'   then case when l_person then 'ID Type'       else 'Registration Type' end
                   when 'INCORPORATION_DATE'  then case when l_person then 'Date of Birth' else 'Incorporation Date' end
                   when 'ADDRESS'             then case when l_person then 'Address'       else 'Headquarters Address' end
               end;
    end field_label;

    -- private (release 99): the labels of the requester's KYC request form (Create Request) where they differ
    function request_form_label(p_party_type in varchar2, p_field in varchar2) return varchar2 is
        l_person boolean := p_party_type = 'PERSON';
    begin
        return case p_field
                   when 'PARTY_TYPE'         then case when l_person then 'Natural Person (Individual)' else 'Legal Person' end
                   when 'NAME'               then case when l_person then 'Full name as per Official Document (in English)'
                                                       else 'Name (as per CR / Official Documents)' end
                   when 'INCORPORATION_DATE' then case when l_person then 'Date of Birth as per Official Document'
                                                       else field_label(p_party_type, p_field) end
               end;
    end request_form_label;

    function entity_lookup(p_party_type in varchar2) return varchar2 is
    begin
        return 'ENTITY_TYPE';      -- release 26: the organisation's category only (an individual's ID type is REGISTRATION_TYPE)
    end entity_lookup;

    function registration_lookup(p_party_type in varchar2) return varchar2 is
    begin
        return case when p_party_type = 'PERSON' then 'ID_DOCUMENT_TYPE' else 'REGISTRATION_TYPE' end;
    end registration_lookup;

    function norm(p_value in varchar2) return varchar2 is
    begin
        return upper(regexp_replace(p_value, '[^[:alnum:]]', ''));
    end norm;

    function exact_party_id(p_party_type          in varchar2,
                            p_registration_number in varchar2,
                            p_jurisdiction        in varchar2,
                            p_exclude_party_id    in number default null,
                            p_registration_type   in varchar2 default null) return number is
        l_id    varchar2(100) := norm(p_registration_number);
        l_party xxcmp_parties.party_id%type;
    begin
        if l_id is null or p_jurisdiction is null then
            return null;
        end if;
        xxfnd_vpd_pkg.begin_trusted;    -- requesters cannot read the party master; only the ID leaves
        select min(party_id) into l_party
          from xxcmp_parties p
         where p.party_type = p_party_type and p.enabled_flag = 'Y' and p.jurisdiction = p_jurisdiction
           and p.party_status not in ('REJECTED', 'CANCELLED')
           and p.party_id <> nvl(p_exclude_party_id, -1)
           and upper(regexp_replace(p.registration_number, '[^[:alnum:]]', '')) = l_id
           -- the same registration / ID type too: another type (or none recorded) is a different registration
           and nvl(p.registration_type, '#') = nvl(p_registration_type, '#');
        xxfnd_vpd_pkg.end_trusted;
        return l_party;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end exact_party_id;

    function exact_party_number(p_party_type          in varchar2,
                                p_registration_number in varchar2,
                                p_jurisdiction        in varchar2,
                                p_exclude_party_id    in number default null,
                                p_registration_type   in varchar2 default null) return varchar2 is
        l_party number := exact_party_id(p_party_type, p_registration_number, p_jurisdiction, p_exclude_party_id,
                                         p_registration_type);
    begin
        return case when l_party is not null then get_party(l_party).party_number end;
    end exact_party_number;

    function party_error(p_party_id            in number,
                         p_party_type          in varchar2,
                         p_party_name          in varchar2,
                         p_jurisdiction        in varchar2,
                         p_registration_number in varchar2,
                         p_entity_type         in varchar2,
                         p_incorporation_date  in date,
                         p_email               in varchar2,
                         p_phone               in varchar2,
                         p_draft               in varchar2 default 'N',
                         p_match_ack           in varchar2 default 'Y',
                         p_registration_type   in varchar2 default null,
                         p_request_form        in varchar2 default 'N') return varchar2 is
        l_exact varchar2(30);
    begin
        if p_party_type is null or p_party_type not in ('ORGANIZATION', 'PERSON') then
            return 'Choose whether the party is an organisation or an individual.';
        elsif trim(p_party_name) is null then
            return 'Enter the name.';
        elsif p_draft = 'Y' then
            return null;
        elsif p_jurisdiction is null then
            return 'Enter the ' || lower(field_label(p_party_type, 'JURISDICTION')) || '.';
        elsif p_party_type = 'ORGANIZATION' and trim(p_registration_number) is null then
            return 'Enter the registration number.';
        elsif p_party_type = 'ORGANIZATION' and p_entity_type is null then
            return 'Choose the entity type.';
        -- release 100: the registration type (CR, passport, ID ...) is part of the duplicate rule - required on the
        -- request form too
        elsif p_party_type = 'ORGANIZATION' and p_registration_type is null then
            return 'Choose the registration type of the registration number.';
        elsif p_party_type = 'PERSON' and trim(p_registration_number) is not null and p_registration_type is null then
            return 'Choose the ID type of the ID number.';
        elsif trim(p_email) is null and trim(p_phone) is null and p_request_form = 'N' then
            return 'Enter an email or a phone number.';
        elsif trim(p_email) is not null and not regexp_like(trim(p_email), '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
            return 'Enter a valid email.';
        elsif p_incorporation_date > trunc(sysdate) then
            return 'The ' || lower(field_label(p_party_type, 'INCORPORATION_DATE')) || ' cannot be in the future.';
        end if;
        l_exact := exact_party_number(p_party_type, p_registration_number, p_jurisdiction, p_party_id,
                                      p_registration_type);
        -- release 100: on the request form the duplicate is the request's rule (XXCMP_REQUEST_PKG.REQUEST_ERROR: use
        -- the existing party Yes / No)
        if l_exact is not null and p_request_form = 'N' then
            return 'Party ' || l_exact || ' already has this '
                   || lower(case when p_party_type = 'PERSON' then 'ID type' else 'registration type' end) || ', '
                   || lower(field_label(p_party_type, 'REGISTRATION_NUMBER'))
                   || ' and ' || lower(field_label(p_party_type, 'JURISDICTION')) || ': use that party.';
        end if;
        -- similar parties: the user answers the page's dialog (none is this party = Y, a match exists = N); only an
        -- unanswered save is stopped
        if p_match_ack is null
           and party_candidate_count(p_party_type, p_party_name, p_registration_number,
                                                       p_incorporation_date, p_jurisdiction, p_party_id) > 0 then
            return 'Similar parties exist (see Possible Matches): answer whether one of them is this party.';
        end if;
        return null;
    end party_error;

    procedure put_party(p_party_id            in out number,
                        p_party_type          in varchar2,
                        p_party_name          in varchar2,
                        p_jurisdiction        in varchar2,
                        p_registration_number in varchar2,
                        p_entity_type         in varchar2,
                        p_incorporation_date  in date,
                        p_email               in varchar2,
                        p_phone               in varchar2,
                        p_website             in varchar2,
                        p_fax                 in varchar2,
                        p_party_status        in varchar2 default null,
                        p_data_provenance     in varchar2 default null,
                        p_enabled_flag        in varchar2 default null,
                        p_registration_type   in varchar2 default null,
                        p_address             in varchar2 default null) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        if p_party_id is null then
            insert into xxcmp_parties (party_type, party_name, jurisdiction, registration_number, entity_type,
                                       incorporation_date, email, phone, website, fax, party_status, data_provenance,
                                       enabled_flag, registration_type, address)
            values (p_party_type, trim(p_party_name), p_jurisdiction, trim(p_registration_number),
                    case when p_party_type = 'ORGANIZATION' then p_entity_type end,
                    p_incorporation_date, trim(p_email), trim(p_phone), trim(p_website), trim(p_fax),
                    nvl(p_party_status, 'APPROVED'), nvl(p_data_provenance, 'SELF_DECLARED'), nvl(p_enabled_flag, 'Y'),
                    p_registration_type, trim(p_address))
            returning party_id into p_party_id;
        else
            update xxcmp_parties
               set party_type          = p_party_type,
                   party_name          = trim(p_party_name),
                   jurisdiction        = p_jurisdiction,
                   registration_number = trim(p_registration_number),
                   entity_type         = case when p_party_type = 'ORGANIZATION' then p_entity_type end,
                   registration_type   = p_registration_type,
                   incorporation_date  = p_incorporation_date,
                   email               = trim(p_email),
                   phone               = trim(p_phone),
                   website             = trim(p_website),
                   fax                 = trim(p_fax),
                   address             = trim(p_address),
                   party_status        = nvl(p_party_status, party_status),
                   data_provenance     = nvl(p_data_provenance, data_provenance),
                   enabled_flag        = nvl(p_enabled_flag, enabled_flag)
             where party_id = p_party_id;
        end if;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end put_party;

    procedure save_party(p_party_id            in out number,
                         p_party_type          in varchar2,
                         p_party_name          in varchar2,
                         p_jurisdiction        in varchar2,
                         p_registration_number in varchar2,
                         p_entity_type         in varchar2,
                         p_incorporation_date  in date,
                         p_email               in varchar2,
                         p_phone               in varchar2,
                         p_website             in varchar2 default null,
                         p_fax                 in varchar2 default null,
                         p_data_provenance     in varchar2 default null,
                         p_enabled_flag        in varchar2 default null,
                         p_match_ack           in varchar2 default 'Y',
                         p_request_id          in number   default null,
                         p_registration_type   in varchar2 default null,
                         p_address             in varchar2 default null) is
        l_error varchar2(4000);
        -- a requester adds an owner / officer to the party created by their request: a Pending party
        l_req_ok boolean := p_party_id is null and p_request_id is not null
                            and xxcmp_request_pkg.party_editable(p_request_id) = 'Y';
    begin
        if p_party_id is null and not l_req_ok and not xxfnd_privilege_pkg.has_privilege('PARTIES', 'CREATE') then
            xxfnd_error_pkg.raise_error('KYC_PARTY_CREATE_NOT_ALLOWED');
        elsif p_party_id is not null and not xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') then
            xxfnd_error_pkg.raise_error('KYC_PARTY_CHANGE_NOT_ALLOWED');
        elsif p_party_id is not null and is_enabled(p_party_id) = 'N' and nvl(p_enabled_flag, 'N') = 'N' then
            xxfnd_error_pkg.raise_error('KYC_PARTY_DISABLED');
        end if;
        l_error := party_error(p_party_id, p_party_type, p_party_name, p_jurisdiction, p_registration_number,
                               p_entity_type, p_incorporation_date, p_email, p_phone, 'N', p_match_ack, p_registration_type);
        if l_error is not null then
            raise_application_error(-20705, l_error);
        end if;
        put_party(p_party_id, p_party_type, p_party_name, p_jurisdiction, p_registration_number, p_entity_type,
                  p_incorporation_date, p_email, p_phone, p_website, p_fax,
                  case when l_req_ok and not xxfnd_privilege_pkg.has_privilege('PARTIES', 'CREATE') then 'PENDING' end,
                  p_data_provenance, p_enabled_flag, p_registration_type, p_address);
    end save_party;

    function request_party(p_request_id in number) return number is
        l_party number;
    begin
        -- data security: only a request the user can see
        select max(party_id) into l_party from xxcmp_requests where request_id = p_request_id;
        return l_party;
    end request_party;

    function can_view(p_party_id in number, p_request_id in number default null) return varchar2 is
        l_status xxcmp_parties.party_status%type;
        l_flag   xxcmp_parties.enabled_flag%type;
    begin
        if p_party_id is null then
            return 'N';
        elsif xxfnd_privilege_pkg.has_privilege('PARTIES', 'VIEW')
              or (p_request_id is not null and request_party(p_request_id) = p_party_id) then
            return 'Y';
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        select max(party_status), max(enabled_flag) into l_status, l_flag from xxcmp_parties where party_id = p_party_id;
        xxfnd_vpd_pkg.end_trusted;
        return case when l_status = 'APPROVED' and l_flag = 'Y' then 'Y' else 'N' end;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end can_view;

    function can_edit_details(p_party_id in number, p_request_id in number default null) return varchar2 is
    begin
        if p_party_id is null then
            return 'N';
        elsif p_request_id is not null then
            return case when request_party(p_request_id) = p_party_id
                         and xxcmp_request_pkg.party_editable(p_request_id) = 'Y' then 'Y' else 'N' end;
        end if;
        return case when xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') and is_enabled(p_party_id) = 'Y'
                    then 'Y' else 'N' end;
    end can_edit_details;

    function details_authorized(p_level in varchar2) return boolean is
    begin
        return xxfnd_user_pkg.authorized('PAGE_' || upper(p_level))
            or can_edit_details(to_number(v('P0_SUMMARY_PARTY_ID')), to_number(v('P0_REQUEST_ID'))) = 'Y';
    end details_authorized;

    function owners_json(p_party_id in number, p_request_id in number default null) return clob is
        l_json clob;
    begin
        if can_view(p_party_id, p_request_id) = 'N' then
            return '[]';
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        select json_arrayagg(json_object(
                   'party_relationship_id' value r.party_relationship_id,
                   'direction'             value case when r.object_party_id = p_party_id then 'Holds interest in this party'
                                                      else 'This party holds interest in' end,
                   'related_party'         value o.party_name || ' (' || o.party_number || ')',
                   'relationship_type'     value xxfnd_lookup_pkg.lookup_meaning('RELATIONSHIP_TYPE', r.relationship_type),
                   'ownership_percentage'  value r.ownership_percentage,
                   'start_date'            value to_char(r.start_date, 'DD-MON-YYYY'),
                   'end_date'              value to_char(r.end_date, 'DD-MON-YYYY'),
                   -- release 73: beneficial owner, marked on the relationship
                   'beneficial_owner'      value case when r.beneficial_owner_flag = 'Y'
                                                      then 'Yes - ' || xxfnd_lookup_pkg.lookup_meaning('UBO_BASIS', r.ubo_basis) end)
                   order by r.end_date nulls first, o.party_name returning clob)
          into l_json
          from xxcmp_party_relationships r
          join xxcmp_parties o
            on o.party_id = case when r.object_party_id = p_party_id then r.subject_party_id else r.object_party_id end
         where p_party_id in (r.object_party_id, r.subject_party_id);
        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_json, '[]');
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end owners_json;

    function ownership_tree_json(p_party_id in number, p_request_id in number default null, p_case_id in number default null) return clob is
        l_json clob;
    begin
        if can_view(p_party_id, p_request_id) = 'N' then
            return '[]';
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        with roots as (
            -- the case's party itself (case screen only)
            select 0 grp, 0 lvl, cast(null as number) rel_id, p.party_id, cast(null as number) parent_id,
                   ':' || p.party_id || ':' path, cast('Party' as varchar2(400)) direction
              from xxcmp_parties p
             where p.party_id = p_party_id and p_case_id is not null
            union all
            -- the parties this party holds an interest in (one level)
            select 2, 1, r.party_relationship_id, r.object_party_id, r.subject_party_id,
                   ':' || p_party_id || ':' || r.object_party_id || ':', 'This party holds interest in'
              from xxcmp_party_relationships r
             where r.subject_party_id = p_party_id
            union all
            -- the parties that hold an interest in this party
            select 1, 1, r.party_relationship_id, r.subject_party_id, r.object_party_id,
                   ':' || p_party_id || ':' || r.subject_party_id || ':', 'Holds interest in this party'
              from xxcmp_party_relationships r
             where r.object_party_id = p_party_id
        ), tree (grp, lvl, rel_id, party_id, parent_id, path, direction) as (
            select grp, lvl, rel_id, party_id, parent_id, path, direction from roots
            union all
            -- ... and those that hold an interest in them
            select t.grp, t.lvl + 1, r.party_relationship_id, r.subject_party_id, r.object_party_id,
                   t.path || r.subject_party_id || ':', 'Holds interest in ' || '#PARENT#'
              from tree t
              join xxcmp_party_relationships r on r.object_party_id = t.party_id
             where t.lvl between 1 and 5
               and t.grp = 1
               and instr(t.path, ':' || r.subject_party_id || ':') = 0
        ) search depth first by grp, party_id set ord
        select json_arrayagg(json_object(
                   'party_relationship_id' value t.rel_id,
                   'grp'                   value t.grp,
                   'lvl'                   value t.lvl,
                   'direction'             value replace(t.direction, '#PARENT#', pp.party_name),
                   'related_party_id'      value o.party_id,
                   'related_party'         value o.party_name || ' (' || o.party_number || ')',
                   'party_type'            value xxfnd_lookup_pkg.lookup_meaning('PARTY_TYPE', o.party_type),
                   'party_type_code'       value o.party_type,
                   'relationship_type'     value xxfnd_lookup_pkg.lookup_meaning('RELATIONSHIP_TYPE', r.relationship_type),
                   'ownership_percentage'  value r.ownership_percentage,
                   'start_date'            value to_char(r.start_date, 'DD-MON-YYYY'),
                   'end_date'              value to_char(r.end_date, 'DD-MON-YYYY'),
                   'country'               value xxfnd_lookup_pkg.lookup_meaning('JURISDICTION', o.jurisdiction),
                   'birth_date'            value to_char(o.incorporation_date, 'DD-MON-YYYY'),
                   'id_number'             value o.registration_number,
                   'id_expiry'             value (select to_char(max(d.expiry_date), 'DD-MON-YYYY')
                                                    from xxfnd_attached_documents_v d
                                                   where d.entity_name = 'XXCMP_PARTIES' and d.pk1_value = to_char(o.party_id)),
                   'screening_id'          value s.screening_id,
                   'results'               value xxfnd_lookup_pkg.lookup_meaning('SCREENING_MATCH_STATUS', s.match_status),
                   'conclusion'            value s.result_notes,
                   'source'                value s.source_reference,
                   'risk_tier'             value xxfnd_lookup_pkg.lookup_meaning('RISK_TIER', s.risk_tier))
                   order by t.ord returning clob)
          into l_json
          from tree t
          join xxcmp_parties o on o.party_id = t.party_id
          left join xxcmp_parties pp on pp.party_id = t.parent_id
          left join xxcmp_party_relationships r on r.party_relationship_id = t.rel_id
          left join lateral (select x.screening_id, x.match_status, x.result_notes, x.source_reference, x.risk_tier
                               from xxcmp_screenings x
                              where p_case_id is not null and x.case_id = p_case_id and x.party_id = o.party_id
                              order by x.screened_date desc nulls last, x.screening_id desc
                              fetch first 1 row only) s on 1 = 1;
        xxfnd_vpd_pkg.end_trusted;
        return nvl(l_json, '[]');
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end ownership_tree_json;

    function party_type(p_party_id in number) return varchar2 is
        l_type xxcmp_parties.party_type%type;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(party_type) into l_type from xxcmp_parties where party_id = p_party_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_type;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end party_type;

    function party_status(p_party_id in number) return varchar2 is
        l_status xxcmp_parties.party_status%type;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select max(party_status) into l_status from xxcmp_parties where party_id = p_party_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_status;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end party_status;

    function get_party(p_party_id in number) return xxcmp_parties%rowtype is
        l_party xxcmp_parties%rowtype;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_party from xxcmp_parties where party_id = p_party_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_party;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end get_party;

    function dff_html(p_party_id in number, p_request_id in number, p_context_code in varchar2, p_edit in varchar2) return clob is
        -- HTML unavoidable, and not built here (release 90): the flexfield's fields are defined at run time, so no APEX
        -- component can show them; COMMON's reusable XXFND_DFF_PKG.RENDER draws them (its reason comment is there). KYC adds
        -- only the party's access rules and the trusted read (a requester cannot read XXCMP_PARTIES).
        l_html clob;
    begin
        if can_view(p_party_id, p_request_id) = 'N' then
            return null;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        l_html := xxfnd_dff_pkg.render(p_table_name      => 'XXCMP_PARTIES',
                                       p_pk_value        => to_char(p_party_id),
                                       p_context_code    => p_context_code,
                                       p_reference_value => party_type(p_party_id),
                                       p_read_only       => case when p_edit = 'Y' and can_edit_details(p_party_id, p_request_id) = 'Y'
                                                                 then 'N' else 'Y' end);
        xxfnd_vpd_pkg.end_trusted;
        return l_html;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end dff_html;

    function dff_error(p_party_id in number, p_values_json in clob, p_context_code in varchar2) return varchar2 is
    begin
        return xxfnd_dff_pkg.validate('XXCMP_PARTIES', p_values_json, p_context_code, to_char(p_party_id), party_type(p_party_id));
    end dff_error;

    procedure save_dff(p_party_id in number, p_request_id in number, p_values_json in clob, p_context_code in varchar2) is
    begin
        if can_edit_details(p_party_id, p_request_id) = 'N' then
            xxfnd_error_pkg.raise_error('KYC_PARTY_THIS_NOT_ALLOWED');
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        xxfnd_dff_pkg.save('XXCMP_PARTIES', to_char(p_party_id), p_values_json, p_context_code, party_type(p_party_id));
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end save_dff;

    procedure set_status(p_party_id in number, p_status in varchar2) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        update xxcmp_parties set party_status = p_status where party_id = p_party_id and party_status <> p_status;
        xxfnd_vpd_pkg.end_trusted;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end set_status;

    procedure load_items(p_party_id in number, p_read_only in varchar2 default 'N') is
        l_p     xxcmp_parties%rowtype;
        l_mine  pls_integer;

        procedure put(p_item in varchar2, p_value in varchar2) is
        begin
            apex_util.set_session_state(p_item, p_value);
        end put;
    begin
        if p_party_id is not null then
            xxfnd_vpd_pkg.begin_trusted;
            select count(*) into l_mine from xxcmp_requests
             where party_id = p_party_id and upper(requester_user_name) = upper(xxfnd_util_pkg.current_user);
            if l_mine > 0 or xxfnd_privilege_pkg.has_privilege('PARTIES', 'VIEW') then
                select * into l_p from xxcmp_parties where party_id = p_party_id;
            end if;
            xxfnd_vpd_pkg.end_trusted;
        end if;
        put('P0_PARTY_ID',                  to_char(l_p.party_id));
        put('P0_PARTY_NUMBER',              l_p.party_number);
        put('P0_PARTY_TYPE',                nvl(l_p.party_type, 'ORGANIZATION'));
        put('P0_PARTY_NAME',                l_p.party_name);
        put('P0_PARTY_JURISDICTION',        l_p.jurisdiction);
        put('P0_PARTY_REGISTRATION_NUMBER', l_p.registration_number);
        put('P0_PARTY_ENTITY_TYPE',         l_p.entity_type);
        put('P0_PARTY_REGISTRATION_TYPE',   l_p.registration_type);
        put('P0_PARTY_INCORPORATION_DATE',  to_char(l_p.incorporation_date));
        put('P0_PARTY_EMAIL',               l_p.email);
        put('P0_PARTY_PHONE',               l_p.phone);
        put('P0_PARTY_WEBSITE',             l_p.website);
        put('P0_PARTY_FAX',                 l_p.fax);
        put('P0_PARTY_ADDRESS',             l_p.address);
        put('P0_PARTY_DATA_PROVENANCE',     nvl(l_p.data_provenance, 'SELF_DECLARED'));
        put('P0_PARTY_LAST_VERIFIED_DATE',  to_char(l_p.last_verified_date, 'DD-MON-YYYY'));
        put('P0_PARTY_STATUS',              xxfnd_lookup_pkg.lookup_meaning('PARTY_STATUS', l_p.party_status));
        put('P0_PARTY_NEXT_KYC_DATE',       to_char(l_p.next_kyc_date, 'DD-MON-YYYY'));
        put('P0_PARTY_ENABLED_FLAG',        nvl(l_p.enabled_flag, 'Y'));
        put('P0_PARTY_READ_ONLY',           case when p_read_only = 'Y' then 'Y' else 'N' end);
        put('P0_PARTY_MATCH_ACK',           null);   -- answered in the similar-parties dialog on each save
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end load_items;

    function relationship_error(p_relationship_id   in number,
                                p_object_party_id   in number,
                                p_relationship_type in varchar2,
                                p_percentage        in number,
                                p_start_date        in date,
                                p_end_date          in date) return varchar2 is
        l_total number;
    begin
        if p_relationship_type is null then
            return 'Choose the relationship.';
        elsif instr(c_ownership_types, ':' || p_relationship_type || ':') > 0 and p_percentage is null then
            return 'Enter the ownership % of a ' || lower(xxfnd_lookup_pkg.lookup_meaning('RELATIONSHIP_TYPE', p_relationship_type)) || '.';
        elsif instr(c_ownership_types, ':' || p_relationship_type || ':') = 0 and p_percentage is not null then
            return 'Ownership % applies only to shareholders, beneficial owners and parent companies.';
        elsif p_percentage not between 0 and 100 then
            return 'Ownership % is between 0 and 100.';
        elsif p_end_date < p_start_date then
            return 'The end date cannot be before the start date.';
        end if;
        if p_percentage is not null and (p_end_date is null or p_end_date >= trunc(sysdate)) then
            select nvl(sum(ownership_percentage), 0) into l_total
              from xxcmp_party_relationships
             where object_party_id = p_object_party_id
               and party_relationship_id <> nvl(p_relationship_id, -1)
               and instr(c_ownership_types, ':' || relationship_type || ':') > 0
               and (end_date is null or end_date >= trunc(sysdate));
            if l_total + p_percentage > 100 then
                return 'The active owners would hold ' || (l_total + p_percentage) || '%: at most 100% (others hold '
                       || l_total || '%).';
            end if;
        end if;
        return null;
    end relationship_error;

    procedure merge_parties(p_from_party_id in number, p_into_party_id in number, p_note in varchar2 default null) is
        l_from xxcmp_parties%rowtype;
        l_into xxcmp_parties%rowtype;
    begin
        if not xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') then
            xxfnd_error_pkg.raise_error('KYC_PARTY_MERGE_NOT_ALLOWED');
        elsif p_from_party_id is null or p_into_party_id is null or p_from_party_id = p_into_party_id then
            xxfnd_error_pkg.raise_error('KYC_PARTY_MERGE_TARGET');
        end if;
        select * into l_from from xxcmp_parties where party_id = p_from_party_id for update;
        select * into l_into from xxcmp_parties where party_id = p_into_party_id for update;
        if l_from.party_type <> l_into.party_type then
            xxfnd_error_pkg.raise_error('KYC_PARTY_MERGE_TYPE');
        elsif l_from.enabled_flag = 'N' or l_into.enabled_flag = 'N' then
            xxfnd_error_pkg.raise_error('KYC_PARTY_MERGE_DISABLED');
        end if;

        -- everything recorded against the duplicate now belongs to the kept party
        update xxcmp_requests   set party_id = p_into_party_id,
                                    match_status = case when party_selection = 'NEW' then 'MERGED' else match_status end,
                                    match_resolved_by = xxfnd_util_pkg.current_user, match_resolved_date = systimestamp
         where party_id = p_from_party_id;
        update xxcmp_cases      set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_screenings set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_alerts     set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_case_notes set related_party_id = p_into_party_id where related_party_id = p_from_party_id;
        -- contacts move as non-primary (the kept party keeps its primary contact)
        update xxcmp_party_contacts set party_id = p_into_party_id, primary_flag = 'N' where party_id = p_from_party_id;
        -- relationships: a relationship between the two parties would point to itself
        delete from xxcmp_party_relationships
         where (subject_party_id = p_from_party_id and object_party_id = p_into_party_id)
            or (subject_party_id = p_into_party_id and object_party_id = p_from_party_id);
        update xxcmp_party_relationships set subject_party_id = p_into_party_id where subject_party_id = p_from_party_id;
        update xxcmp_party_relationships set object_party_id  = p_into_party_id where object_party_id  = p_from_party_id;
        -- identity and registry checks (release 74)
        update xxcmp_party_id_verifications set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_party_registry_checks  set party_id = p_into_party_id where party_id = p_from_party_id;
        -- documents (release 87: COMMON moves them, with their versions)
        xxfnd_attach_pkg.move_documents('XXCMP_PARTIES', to_char(p_from_party_id), to_char(p_into_party_id));

        -- the kept party's empty details are completed from the duplicate
        update xxcmp_parties
           set registration_number = nvl(registration_number, l_from.registration_number),
               entity_type         = nvl(entity_type, l_from.entity_type),
               registration_type   = nvl(registration_type, l_from.registration_type),
               incorporation_date  = nvl(incorporation_date, l_from.incorporation_date),
               jurisdiction        = nvl(jurisdiction, l_from.jurisdiction),
               email               = nvl(email, l_from.email),
               phone               = nvl(phone, l_from.phone),
               website             = nvl(website, l_from.website),
               fax                 = nvl(fax, l_from.fax),
               address             = nvl(address, l_from.address)
         where party_id = p_into_party_id;
        update xxcmp_parties
           set enabled_flag = 'N', merged_into_party_id = p_into_party_id, merge_note = substr(p_note, 1, 1000)
         where party_id = p_from_party_id;
    end merge_parties;

    function is_enabled(p_party_id in number) return varchar2 is
        l_flag xxcmp_parties.enabled_flag%type;
    begin
        xxfnd_vpd_pkg.begin_trusted;    -- also asked for a requester's chosen party
        select max(enabled_flag) into l_flag from xxcmp_parties where party_id = p_party_id;
        xxfnd_vpd_pkg.end_trusted;
        return case when l_flag = 'Y' then 'Y' else 'N' end;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end is_enabled;

    function card_json(p_party_id in number, p_request_id in number default null, p_show_status in varchar2 default 'Y',
                       p_request_form in varchar2 default 'N') return clob is
        l_p      xxcmp_parties%rowtype;
        l_status varchar2(1) := case when p_request_id is null then nvl(p_show_status, 'Y') else 'N' end;
        l_rows   json_array_t := json_array_t();
        l_seq    pls_integer := 0;
        l_found  boolean := false;

        procedure fld(p_group in varchar2, p_label in varchar2, p_value in varchar2, p_meta in varchar2 default null,
                      p_tone in varchar2 default null, p_url in varchar2 default null) is
            l_row json_object_t := json_object_t();
        begin
            if p_value is not null then
                l_seq := l_seq + 10;
                l_row.put('group_name', p_group);
                l_row.put('seq', l_seq);
                l_row.put('label', p_label);
                l_row.put('value', p_value);
                l_row.put('meta', p_meta);
                l_row.put('tone', p_tone);
                l_row.put('url', p_url);
                l_rows.append(l_row);
            end if;
        end fld;
    begin
        if p_party_id is null then
            return '[]';
        elsif can_view(p_party_id, p_request_id) = 'N' then
            fld('Party', 'Party', 'The party details are available to Compliance.');
            return l_rows.to_clob;
        end if;
        xxfnd_vpd_pkg.begin_trusted;     -- can_view decided; requesters see their request's party this way
        for r in (select * from xxcmp_parties where party_id = p_party_id) loop
            l_p := r;
            l_found := true;
        end loop;
        if l_found then
            fld('Party', case when p_request_form = 'Y' then request_form_label(l_p.party_type, 'NAME') else 'Name' end,
                l_p.party_name);
            fld('Party', 'Party Number', l_p.party_number, null, null,
                case when p_request_id is null and xxfnd_privilege_pkg.has_privilege('PARTIES', 'VIEW')
                     then apex_page.get_url(p_page => 21, p_items => 'P21_PARTY_ID', p_values => to_char(l_p.party_id),
                                            p_clear_cache => '21') end);
            if l_status = 'Y' then
                if l_p.merged_into_party_id is not null then
                    for m in (select party_number from xxcmp_parties where party_id = l_p.merged_into_party_id) loop
                        fld('Party', 'Status', 'Merged into ' || m.party_number, null, 'neutral');
                    end loop;
                elsif l_p.enabled_flag = 'N' then
                    fld('Party', 'Status', 'Disabled', null, 'neutral');
                else
                    fld('Party', 'Status', xxfnd_lookup_pkg.lookup_meaning('PARTY_STATUS', l_p.party_status), null,
                        xxfnd_ui_pkg.status_tone('PARTY', l_p.party_status));
                end if;
            end if;
            fld('Identity', 'Type', case when p_request_form = 'Y' then request_form_label(l_p.party_type, 'PARTY_TYPE')
                                         else xxfnd_lookup_pkg.lookup_meaning('PARTY_TYPE', l_p.party_type) end);
            if l_p.party_type = 'ORGANIZATION' then
                fld('Identity', 'Entity Type', xxfnd_lookup_pkg.lookup_meaning('ENTITY_TYPE', l_p.entity_type));
            end if;
            fld('Identity', field_label(l_p.party_type, 'JURISDICTION'), xxfnd_lookup_pkg.lookup_meaning('JURISDICTION', l_p.jurisdiction));
            fld('Identity', field_label(l_p.party_type, 'REGISTRATION_NUMBER'), l_p.registration_number,
                -- release 100: the registration type is shown on the request form too (part of the duplicate rule)
                xxfnd_lookup_pkg.lookup_meaning(registration_lookup(l_p.party_type), l_p.registration_type));
            if p_request_form = 'N' then
                fld('Identity', field_label(l_p.party_type, 'INCORPORATION_DATE'), to_char(l_p.incorporation_date, 'DD-MON-YYYY'));
                fld('Contact', 'Email', l_p.email, null, null, case when l_p.email is not null then 'mailto:' || l_p.email end);
                fld('Contact', 'Phone', l_p.phone);
                fld('Contact', 'Website', l_p.website);
            elsif l_p.party_type = 'PERSON' then
                fld('Identity', request_form_label(l_p.party_type, 'INCORPORATION_DATE'), to_char(l_p.incorporation_date, 'DD-MON-YYYY'));
            end if;
            fld('Contact', field_label(l_p.party_type, 'ADDRESS'), l_p.address);
            for c in (select contact_name as name, job_title, email, phone
                        from xxcmp_party_contacts
                       where party_id = p_party_id and enabled_flag = 'Y'
                       order by primary_flag desc, party_contact_id
                       fetch first 1 row only) loop
                fld('Contact', 'Contact Person', c.name || nvl2(c.job_title, ' · ' || c.job_title, null),
                    ltrim(c.email || nvl2(c.phone, ' · ' || c.phone, null), ' ·'));
            end loop;
            if l_status = 'Y' then
                fld('KYC', 'Last Verified', to_char(l_p.last_verified_date, 'DD-MON-YYYY'));
                fld('KYC', 'Next KYC Date', to_char(l_p.next_kyc_date, 'DD-MON-YYYY'));
            end if;
        end if;
        xxfnd_vpd_pkg.end_trusted;
        return l_rows.to_clob;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end card_json;

    function can_record_verification(p_party_id in number, p_case_id in number default null) return varchar2 is
    begin
        if p_party_id is null or is_enabled(p_party_id) = 'N' or not xxfnd_privilege_pkg.has_privilege('PARTIES', 'CREATE') then
            return 'N';
        elsif p_case_id is not null then
            return xxcmp_case_pkg.is_editable(p_case_id);     -- the case decides when it can still be changed
        end if;
        return 'Y';
    end can_record_verification;

    function id_verification_error(p_party_id        in number,
                                   p_document_number in varchar2,
                                   p_issue_date      in date,
                                   p_expiry_date     in date,
                                   p_result          in varchar2) return varchar2 is
        l_type xxcmp_parties.party_type%type := party_type(p_party_id);
    begin
        if l_type is null then
            return 'Choose the party.';
        elsif l_type <> 'PERSON' then
            return 'Identity documents are checked for individuals; check an organisation in the company registry.';
        elsif trim(p_document_number) is null then
            return 'Enter the document number.';
        elsif p_issue_date > trunc(sysdate) then
            return 'The issue date cannot be in the future.';
        elsif p_expiry_date < p_issue_date then
            return 'The expiry date cannot be before the issue date.';
        elsif p_result = 'VERIFIED' and p_expiry_date < trunc(sysdate) then
            return 'An expired document cannot be recorded as verified.';
        end if;
        return null;
    end id_verification_error;

    function registry_check_error(p_party_id      in number,
                                  p_source        in varchar2,
                                  p_endpoint_code in varchar2,
                                  p_check_result  in varchar2) return varchar2 is
        l_type xxcmp_parties.party_type%type := party_type(p_party_id);
    begin
        if l_type is null then
            return 'Choose the party.';
        elsif l_type <> 'ORGANIZATION' then
            return 'The company registry is checked for organisations; check an individual''s identity document.';
        elsif p_source = 'API' and p_endpoint_code is null then
            return 'A check from a provider names the provider.';
        elsif p_check_result is null then
            return 'Choose the result of the check.';
        end if;
        return null;
    end registry_check_error;

    procedure registry_check_saved(p_registry_check_id in number) is
    begin
        update xxcmp_party_registry_checks set changed_by_person_flag = 'Y'
         where registry_check_id = p_registry_check_id and source = 'API' and changed_by_person_flag = 'N';
    end registry_check_saved;

end xxcmp_party_pkg;
/
