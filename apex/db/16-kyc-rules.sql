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

-- release 54: XXFND_INT_PURPOSES_MC (shared table) is created by script 09c (COMMON).

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

    -- release 74: requests for information are the common RFI workflow (XXFND_RFI_PKG, COMMON 15c).

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
               and incorporation_date = p_date_of_birth      -- an individual's date of birth
               and upper(party_name) = upper(p_party_name)
               and enabled_flag = 'Y';
        end if;
        return l_id;
    end exact_party_match;


end xxcmp_kyc_pkg;
/
