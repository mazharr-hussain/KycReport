--------------------------------------------------------------------------------
-- 16e Party logic (party feature: pages 20-24, and the common party region on the Global Page)
--   XXCMP_PARTY_PKG: the rules and save of the common party form (Party dialog 24, Create Request
--   step 1 on 201, new owner / officer on 23), party status, owner / officer rules, the merge of a
--   duplicate party (Compliance) and the common party card. Runs after 16b/16c: the merge re-points
--   requests, cases, screenings, alerts, notes and beneficial-owner decisions.
-- Organisation / individual share one column per pair: JURISDICTION = country / nationality,
-- REGISTRATION_NUMBER = registration / ID number, ENTITY_TYPE = entity / ID type (lookup
-- ENTITY_TYPE / ID_DOCUMENT_TYPE), INCORPORATION_DATE = incorporation / birth date.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxcmp_party_pkg authid definer as

    -- Label of a shared party field for the party type: JURISDICTION, REGISTRATION_NUMBER, ENTITY_TYPE,
    -- INCORPORATION_DATE (for example Registration No. / ID Number).
    function field_label(p_party_type in varchar2, p_field in varchar2) return varchar2;
    -- Lookup type of ENTITY_TYPE for the party type (ENTITY_TYPE / ID_DOCUMENT_TYPE).
    function entity_lookup(p_party_type in varchar2) return varchar2;

    -- Party number of another enabled party with the same type, registration / ID number (ignoring spaces and
    -- punctuation) and country, or null. Reads the whole party master (trusted); returns only the number.
    function exact_party_number(p_party_type          in varchar2,
                                p_registration_number in varchar2,
                                p_jurisdiction        in varchar2,
                                p_exclude_party_id    in number default null) return varchar2;

    -- The rules of the common party form (null = acceptable). Type, name and country required;
    -- organisation: registration number and entity type required; individual: ID type required when an
    -- ID number is given; email or phone required (email must be valid); the date not in the future;
    -- no other party with the same number and country; when similar parties exist the user must confirm
    -- (P_MATCH_ACK = Y) that none of them is this party. P_DRAFT = Y checks only the type and the name.
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
                         p_match_ack           in varchar2 default 'Y') return varchar2;

    -- Inserts (P_PARTY_ID null) or updates the party's form fields, without a privilege check (the request
    -- package creates the Pending party of a request through it). A new party is APPROVED unless
    -- P_PARTY_STATUS says otherwise. Null P_DATA_PROVENANCE / P_ENABLED_FLAG keep the current values.
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
                        p_enabled_flag        in varchar2 default null);

    -- Compliance saves the common party form (Party dialog, new owner / officer): Parties - Create for a new
    -- party, Parties - Manage to change one; the form rules apply. A party created here is Approved.
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
                         p_match_ack           in varchar2 default 'Y');

    -- Party status: PENDING, APPROVED, REJECTED, CANCELLED.
    procedure set_status(p_party_id in number, p_status in varchar2);

    -- Fills the items of the common party region (P0_PARTY_*) with the party, or empties them for a new party.
    -- Compliance (Parties - View) reads any party; a requester only a party of one of their own requests.
    -- P_READ_ONLY = Y shows the region read only.
    procedure load_items(p_party_id in number, p_read_only in varchar2 default 'N');

    -- Owner / officer rules (null = acceptable): Ownership % required for Shareholder, Beneficial Owner and
    -- Parent Company and empty for the other types; the active owners of a party hold at most 100%.
    function relationship_error(p_relationship_id   in number,
                                p_object_party_id   in number,
                                p_relationship_type in varchar2,
                                p_percentage        in number,
                                p_start_date        in date,
                                p_end_date          in date) return varchar2;

    -- Compliance merges the duplicate P_FROM_PARTY_ID into P_INTO_PARTY_ID (Parties - Manage): requests, cases,
    -- screenings, alerts, notes, beneficial-owner decisions, contacts, relationships and documents move to the
    -- kept party; its empty details are completed from the duplicate; the duplicate is disabled and points to it.
    procedure merge_parties(p_from_party_id in number, p_into_party_id in number, p_note in varchar2 default null);

    -- Y when the party exists and is enabled (a merged or disabled party is not edited or merged again).
    function is_enabled(p_party_id in number) return varchar2;

    -- The common Party card (HTML) shown on every screen that shows a party: number, name, type, registration /
    -- identity, country, main contact details, primary contact person, party status and next KYC date. Follows
    -- data security: a user who may not see the party gets a short note instead.
    function card_html(p_party_id in number) return clob;
    -- Party summary line with the card in an expander (Global Page region on 201 / 203 / 205). Shown to users with
    -- PARTIES.VIEW, and to anyone for the party of a request they can see or for an approved party.
    function summary_html(p_party_id in number, p_request_id in number default null) return clob;

end xxcmp_party_pkg;
/

create or replace package body xxcmp_party_pkg as

    -- relationship types that are ownership (Ownership % required)
    c_ownership_types constant varchar2(200) := ':SHAREHOLDER:BENEFICIAL_OWNER:PARENT_COMPANY:';

    function field_label(p_party_type in varchar2, p_field in varchar2) return varchar2 is
        l_person boolean := p_party_type = 'PERSON';
    begin
        return case p_field
                   when 'JURISDICTION'        then case when l_person then 'Nationality'   else 'Country' end
                   when 'REGISTRATION_NUMBER' then case when l_person then 'ID Number'     else 'Registration No.' end
                   when 'ENTITY_TYPE'         then case when l_person then 'ID Type'       else 'Entity Type' end
                   when 'INCORPORATION_DATE'  then case when l_person then 'Date of Birth' else 'Incorporation Date' end
               end;
    end field_label;

    function entity_lookup(p_party_type in varchar2) return varchar2 is
    begin
        return case when p_party_type = 'PERSON' then 'ID_DOCUMENT_TYPE' else 'ENTITY_TYPE' end;
    end entity_lookup;

    function norm(p_value in varchar2) return varchar2 is
    begin
        return upper(regexp_replace(p_value, '[^[:alnum:]]', ''));
    end norm;

    function exact_party_number(p_party_type          in varchar2,
                                p_registration_number in varchar2,
                                p_jurisdiction        in varchar2,
                                p_exclude_party_id    in number default null) return varchar2 is
        l_id     varchar2(100) := norm(p_registration_number);
        l_number xxcmp_parties.party_number%type;
    begin
        if l_id is null or p_jurisdiction is null then
            return null;
        end if;
        xxfnd_vpd_pkg.begin_trusted;    -- requesters cannot read the party master; only the number leaves
        select min(party_number) into l_number
          from xxcmp_parties p
         where p.party_type = p_party_type and p.enabled_flag = 'Y' and p.jurisdiction = p_jurisdiction
           and p.party_status not in ('REJECTED', 'CANCELLED')
           and p.party_id <> nvl(p_exclude_party_id, -1)
           and upper(regexp_replace(p.registration_number, '[^[:alnum:]]', '')) = l_id;
        xxfnd_vpd_pkg.end_trusted;
        return l_number;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
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
                         p_match_ack           in varchar2 default 'Y') return varchar2 is
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
        elsif p_party_type = 'PERSON' and trim(p_registration_number) is not null and p_entity_type is null then
            return 'Choose the ID type of the ID number.';
        elsif trim(p_email) is null and trim(p_phone) is null then
            return 'Enter an email or a phone number.';
        elsif trim(p_email) is not null and not regexp_like(trim(p_email), '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
            return 'Enter a valid email.';
        elsif p_incorporation_date > trunc(sysdate) then
            return 'The ' || lower(field_label(p_party_type, 'INCORPORATION_DATE')) || ' cannot be in the future.';
        end if;
        l_exact := exact_party_number(p_party_type, p_registration_number, p_jurisdiction, p_party_id);
        if l_exact is not null then
            return 'Party ' || l_exact || ' already has this ' || lower(field_label(p_party_type, 'REGISTRATION_NUMBER'))
                   || ' and ' || lower(field_label(p_party_type, 'JURISDICTION')) || ': use that party.';
        end if;
        if nvl(p_match_ack, 'N') <> 'Y'
           and xxcmp_request_pkg.party_candidate_count(p_party_type, p_party_name, p_registration_number,
                                                       p_incorporation_date, p_jurisdiction, p_party_id) > 0 then
            return 'Similar parties exist (see Possible Matches): confirm that none of them is this party.';
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
                        p_enabled_flag        in varchar2 default null) is
    begin
        xxfnd_vpd_pkg.begin_trusted;
        if p_party_id is null then
            insert into xxcmp_parties (party_type, party_name, jurisdiction, registration_number, entity_type,
                                       incorporation_date, email, phone, website, fax, party_status, data_provenance,
                                       enabled_flag)
            values (p_party_type, trim(p_party_name), p_jurisdiction, trim(p_registration_number), p_entity_type,
                    p_incorporation_date, trim(p_email), trim(p_phone), trim(p_website), trim(p_fax),
                    nvl(p_party_status, 'APPROVED'), nvl(p_data_provenance, 'SELF_DECLARED'), nvl(p_enabled_flag, 'Y'))
            returning party_id into p_party_id;
        else
            update xxcmp_parties
               set party_type          = p_party_type,
                   party_name          = trim(p_party_name),
                   jurisdiction        = p_jurisdiction,
                   registration_number = trim(p_registration_number),
                   entity_type         = p_entity_type,
                   incorporation_date  = p_incorporation_date,
                   email               = trim(p_email),
                   phone               = trim(p_phone),
                   website             = trim(p_website),
                   fax                 = trim(p_fax),
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
                         p_match_ack           in varchar2 default 'Y') is
        l_error varchar2(4000);
    begin
        if p_party_id is null and not xxfnd_privilege_pkg.has_privilege('PARTIES', 'CREATE') then
            raise_application_error(-20701, 'You are not allowed to create parties.');
        elsif p_party_id is not null and not xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') then
            raise_application_error(-20706, 'You are not allowed to change parties.');
        elsif p_party_id is not null and is_enabled(p_party_id) = 'N' and nvl(p_enabled_flag, 'N') = 'N' then
            raise_application_error(-20707, 'A disabled or merged party cannot be changed.');
        end if;
        l_error := party_error(p_party_id, p_party_type, p_party_name, p_jurisdiction, p_registration_number,
                               p_entity_type, p_incorporation_date, p_email, p_phone, 'N', p_match_ack);
        if l_error is not null then
            raise_application_error(-20705, l_error);
        end if;
        put_party(p_party_id, p_party_type, p_party_name, p_jurisdiction, p_registration_number, p_entity_type,
                  p_incorporation_date, p_email, p_phone, p_website, p_fax, null, p_data_provenance, p_enabled_flag);
    end save_party;

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
        put('P0_PARTY_INCORPORATION_DATE',  to_char(l_p.incorporation_date));
        put('P0_PARTY_EMAIL',               l_p.email);
        put('P0_PARTY_PHONE',               l_p.phone);
        put('P0_PARTY_WEBSITE',             l_p.website);
        put('P0_PARTY_FAX',                 l_p.fax);
        put('P0_PARTY_DATA_PROVENANCE',     nvl(l_p.data_provenance, 'SELF_DECLARED'));
        put('P0_PARTY_LAST_VERIFIED_DATE',  to_char(l_p.last_verified_date, 'DD-MON-YYYY'));
        put('P0_PARTY_STATUS',              xxfnd_util_pkg.lookup_meaning('PARTY_STATUS', l_p.party_status));
        put('P0_PARTY_NEXT_KYC_DATE',       to_char(l_p.next_kyc_date, 'DD-MON-YYYY'));
        put('P0_PARTY_ENABLED_FLAG',        nvl(l_p.enabled_flag, 'Y'));
        put('P0_PARTY_READ_ONLY',           case when p_read_only = 'Y' then 'Y' else 'N' end);
        put('P0_PARTY_MATCH_ACK',           'N');    -- confirmed again on each save when similar parties exist
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
            return 'Enter the ownership % of a ' || lower(xxfnd_util_pkg.lookup_meaning('RELATIONSHIP_TYPE', p_relationship_type)) || '.';
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
        update xxcmp_requests   set party_id = p_into_party_id,
                                    match_status = case when party_selection = 'NEW' then 'MERGED' else match_status end,
                                    match_resolved_by = xxfnd_util_pkg.current_user, match_resolved_date = systimestamp
         where party_id = p_from_party_id;
        update xxcmp_cases      set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_screenings set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_alerts     set party_id = p_into_party_id where party_id = p_from_party_id;
        update xxcmp_case_notes set related_party_id = p_into_party_id where related_party_id = p_from_party_id;
        -- one beneficial-owner decision per case and owner
        delete from xxcmp_ubo_determinations u
         where u.owner_party_id = p_from_party_id
           and exists (select 1 from xxcmp_ubo_determinations k where k.case_id = u.case_id and k.owner_party_id = p_into_party_id);
        update xxcmp_ubo_determinations set owner_party_id = p_into_party_id where owner_party_id = p_from_party_id;
        -- contacts move as non-primary (the kept party keeps its primary contact)
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
        xxfnd_vpd_pkg.begin_trusted;    -- also asked for a requester's chosen party
        select max(enabled_flag) into l_flag from xxcmp_parties where party_id = p_party_id;
        xxfnd_vpd_pkg.end_trusted;
        return case when l_flag = 'Y' then 'Y' else 'N' end;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end is_enabled;

    function card_html(p_party_id in number) return clob is
        l_p      xxcmp_parties%rowtype;
        l_into   xxcmp_parties.party_number%type;
        l_html   clob;
        l_found  boolean := false;

        procedure row(p_label in varchar2, p_value in varchar2, p_raw in boolean default false) is
        begin
            if p_value is not null then
                l_html := l_html || '<dt class="t-AVPList-label">' || apex_escape.html(p_label) || '</dt>'
                               || '<dd class="t-AVPList-value">' || case when p_raw then p_value else apex_escape.html(p_value) end
                               || '</dd>';
            end if;
        end row;
    begin
        if p_party_id is null then
            return '<p class="u-color-subtle">No party linked yet.</p>';
        end if;
        for r in (select * from xxcmp_parties where party_id = p_party_id) loop     -- data security applies
            l_p := r;
            l_found := true;
        end loop;
        if not l_found then
            return '<p class="u-color-subtle">The party details are available to Compliance.</p>';
        end if;
        select max(party_number) into l_into from xxcmp_parties where party_id = l_p.merged_into_party_id;

        l_html := '<dl class="t-AVPList t-AVPList--leftAligned">';
        row('Party', case when xxfnd_privilege_pkg.has_privilege('PARTIES', 'VIEW')
                          then '<a href="' || apex_page.get_url(p_page => 21, p_items => 'P21_PARTY_ID',
                                                                 p_values => to_char(l_p.party_id), p_clear_cache => '21')
                               || '">' || apex_escape.html(l_p.party_number) || '</a>'
                          else apex_escape.html(l_p.party_number) end
                     || ' - ' || apex_escape.html(l_p.party_name), true);
        row('Type', xxfnd_util_pkg.lookup_meaning('PARTY_TYPE', l_p.party_type));
        row(field_label(l_p.party_type, 'REGISTRATION_NUMBER'), l_p.registration_number);
        row(field_label(l_p.party_type, 'ENTITY_TYPE'), xxfnd_util_pkg.lookup_meaning(entity_lookup(l_p.party_type), l_p.entity_type));
        row(field_label(l_p.party_type, 'INCORPORATION_DATE'), to_char(l_p.incorporation_date, 'DD-MON-YYYY'));
        row(field_label(l_p.party_type, 'JURISDICTION'), xxfnd_util_pkg.lookup_meaning('JURISDICTION', l_p.jurisdiction));
        row('Email', l_p.email);
        row('Phone', l_p.phone);
        row('Website', l_p.website);
        for c in (select contact_name as name, job_title, email, phone
                    from xxcmp_party_contacts
                   where party_id = p_party_id and enabled_flag = 'Y'
                   order by primary_flag desc, party_contact_id
                   fetch first 1 row only) loop
            row('Contact Person', c.name || nvl2(c.job_title, ' (' || c.job_title || ')', null)
                                  || nvl2(c.email, ', ' || c.email, null) || nvl2(c.phone, ', ' || c.phone, null));
        end loop;
        row('Party Status', case when l_p.merged_into_party_id is not null then 'Merged into ' || l_into
                                 when l_p.enabled_flag = 'N' then 'Disabled'
                                 else xxfnd_util_pkg.lookup_meaning('PARTY_STATUS', l_p.party_status) end
                            || nvl2(l_p.last_verified_date, ' - verified ' || to_char(l_p.last_verified_date, 'DD-MON-YYYY'), null));
        row('Next KYC Date', to_char(l_p.next_kyc_date, 'DD-MON-YYYY'));
        return l_html || '</dl>';
    end card_html;

    function summary_html(p_party_id in number, p_request_id in number default null) return clob is
        l_ok   boolean := xxfnd_privilege_pkg.has_privilege('PARTIES', 'VIEW');
        l_n    number;
        l_p    xxcmp_parties%rowtype;
        l_card clob;
    begin
        if p_party_id is null then
            return null;
        end if;
        if not l_ok and p_request_id is not null then
            select count(*) into l_n from xxcmp_requests where request_id = p_request_id and party_id = p_party_id;  -- data security
            l_ok := l_n > 0;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        select * into l_p from xxcmp_parties where party_id = p_party_id;
        l_ok := l_ok or (l_p.party_status = 'APPROVED' and l_p.enabled_flag = 'Y');
        if l_ok then
            l_card := card_html(p_party_id);
        end if;
        xxfnd_vpd_pkg.end_trusted;
        if not l_ok then
            return '<p class="u-color-subtle">The party details are available to Compliance.</p>';
        end if;
        return '<p><strong>' || apex_escape.html(l_p.party_name) || '</strong> (' || apex_escape.html(l_p.party_number) || ') - '
               || apex_escape.html(xxfnd_util_pkg.lookup_meaning('PARTY_STATUS', l_p.party_status)) || '</p>'
               || '<details class="kyc-party-details"><summary>Show details</summary>' || l_card || '</details>';
    exception
        when no_data_found then
            xxfnd_vpd_pkg.end_trusted;
            return null;
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end summary_html;

end xxcmp_party_pkg;
/
