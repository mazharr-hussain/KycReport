-- Party feature (release 23): the common party form rules and save (one column per organisation / individual
-- pair), contact persons, owner / officer rules (ownership %), and the Compliance merge of a duplicate party
-- (everything moves to the kept party, the duplicate is disabled).
-- Needs security_test.sql (REQ1, OFFICER1) and at least one closed case (kyc_flow_test.sql).
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_tag   varchar2(20) := dbms_random.string('U', 10);
    l_dup   number;
    l_keep  number;
    l_other number;
    l_new   number;
    l_case  number;
    l_cnt   number;
    l_txt   varchar2(4000);
    l_p     xxcmp_parties%rowtype;

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    procedure session_as(p_user varchar2) is
    begin
        if apex_application.g_instance is not null then
            apex_session.delete_session;
        end if;
        apex_session.create_session(l_app, 1, p_user);
    end;
    function err(p_sqlerrm varchar2) return varchar2 is
    begin
        return regexp_substr(substr(p_sqlerrm, 12), '[^' || chr(10) || ']+');
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';

    ---------------------------------------------------------------- the common party form
    session_as('REQ1');
    begin
        xxcmp_party_pkg.save_party(l_new, 'PERSON', 'Requester Made ' || l_tag, 'AE', null, null, null, null, '+1');
        ok('a requester cannot create parties', false);
    exception when others then
        ok('a requester cannot create parties: ' || err(sqlerrm), sqlcode = -20701);
    end;
    session_as('OFFICER1');
    xxcmp_party_pkg.save_party(l_new, 'PERSON', 'New Director ' || l_tag, 'AE', 'PX-' || l_tag, null,
                               date '1975-05-05', null, '+971 50 1', p_registration_type => 'PASSPORT');
    select * into l_p from xxcmp_parties where party_id = l_new;
    ok('an individual keeps its ID number, ID type, birth date and nationality in the shared columns: ' || l_p.party_number,
       l_p.party_type = 'PERSON' and l_p.registration_number = 'PX-' || l_tag and l_p.registration_type = 'PASSPORT' and l_p.entity_type is null
       and l_p.incorporation_date = date '1975-05-05' and l_p.jurisdiction = 'AE' and l_p.party_status = 'APPROVED');
    ok('labels follow the type', xxcmp_party_pkg.field_label('PERSON', 'REGISTRATION_NUMBER') = 'ID Number'
       and xxcmp_party_pkg.field_label('ORGANIZATION', 'INCORPORATION_DATE') = 'Incorporation Date');
    l_keep := null;
    xxcmp_party_pkg.save_party(l_keep, 'ORGANIZATION', 'Keep Holding ' || l_tag, 'AE', 'KH-' || l_tag, 'LLC', null,
                               'info@keep.example', null, p_registration_type => 'COMMERCIAL_REGISTRATION');
    begin
        l_other := null;
        xxcmp_party_pkg.save_party(l_other, 'ORGANIZATION', 'Other Name ' || l_tag, 'AE', 'kh ' || l_tag, 'LLC', null,
                                   'x@example.com', null, p_registration_type => 'COMMERCIAL_REGISTRATION');
        ok('same registration number and country is refused', false);
    exception when others then
        ok('same registration number and country is refused: ' || err(sqlerrm), sqlcode = -20705);
    end;
    ok('an organisation needs its entity type: ' || xxcmp_party_pkg.party_error(null, 'ORGANIZATION', 'Z ' || l_tag, 'AE',
                                                    'Z-' || l_tag, null, null, 'z@example.com', null),
       xxcmp_party_pkg.party_error(null, 'ORGANIZATION', 'Z ' || l_tag, 'AE', 'Z-' || l_tag, null, null, 'z@example.com', null)
       = 'Choose the entity type.');
    ok('a birth date in the future is refused',
       xxcmp_party_pkg.party_error(null, 'PERSON', 'Z ' || l_tag, 'AE', null, null, sysdate + 5, null, '1')
       = 'The date of birth cannot be in the future.');

    ---------------------------------------------------------------- owners / officers
    ok('a shareholder needs its ownership %',
       xxcmp_party_pkg.relationship_error(null, l_keep, 'SHAREHOLDER', null, sysdate, null) like 'Enter the ownership %');
    ok('a director has no ownership %',
       xxcmp_party_pkg.relationship_error(null, l_keep, 'DIRECTOR', 10, sysdate, null) like 'Ownership % applies only%');
    insert into xxcmp_party_relationships (subject_party_id, object_party_id, relationship_type, ownership_percentage)
    values (l_new, l_keep, 'SHAREHOLDER', 70);
    l_txt := xxcmp_party_pkg.relationship_error(null, l_keep, 'SHAREHOLDER', 40, sysdate, null);
    ok('the active owners hold at most 100%: ' || l_txt, l_txt like 'The active owners would hold 110%%');
    ok('30% more is fine', xxcmp_party_pkg.relationship_error(null, l_keep, 'SHAREHOLDER', 30, sysdate, null) is null);
    delete from xxcmp_party_relationships where subject_party_id = l_new and object_party_id = l_keep;

    ---------------------------------------------------------------- party-level contact details, contact persons
    update xxcmp_parties set email = 'info@keep.example', phone = '+971 4 555 0000', website = 'https://keep.example',
                             fax = '+971 4 555 0001'
     where party_id = l_keep;
    insert into xxcmp_party_contacts (party_id, contact_name, job_title, email, phone, primary_flag)
    values (l_keep, 'Jane Keep', 'Finance Director', 'jane@keep.example', '+971 50 000 0000', 'Y');
    select count(*) into l_cnt from xxcmp_parties
     where party_id = l_keep and email = 'info@keep.example' and website = 'https://keep.example' and fax is not null;
    ok('main email, phone, website and fax are kept on the party', l_cnt = 1);

    ---------------------------------------------------------------- merge a duplicate (with a closed case)
    select max(c.case_id) keep (dense_rank last order by c.case_id), max(c.party_id) keep (dense_rank last order by c.case_id)
      into l_case, l_dup
      from xxcmp_cases c join xxcmp_parties p on p.party_id = c.party_id
     where c.closed_date is not null and p.party_type = 'ORGANIZATION' and p.enabled_flag = 'Y';
    if l_dup is null then
        ok('a closed case of an organisation is needed (run kyc_flow_test.sql first)', false);
        return;
    end if;
    update xxcmp_parties set email = null, website = 'https://dup.example' where party_id = l_dup;
    update xxcmp_parties set website = null where party_id = l_keep;
    insert into xxcmp_party_contacts (party_id, contact_name, email, primary_flag)
    values (l_dup, 'Dup Person', 'dup@dup.example', 'N');
    insert into xxcmp_party_relationships (subject_party_id, object_party_id, relationship_type, ownership_percentage)
    values (l_new, l_dup, 'SHAREHOLDER', 40);
    insert into xxcmp_party_relationships (subject_party_id, object_party_id, relationship_type, ownership_percentage)
    values (l_dup, l_keep, 'SHAREHOLDER', 10);
    commit;

    session_as('REQ1');
    begin
        xxcmp_party_pkg.merge_parties(l_dup, l_keep);
        ok('a requester cannot merge parties', false);
    exception when others then
        ok('a requester cannot merge parties: ' || err(sqlerrm), sqlcode = -20711);
    end;
    session_as('OFFICER1');
    begin
        xxcmp_party_pkg.merge_parties(l_dup, l_new);
        ok('an organisation cannot be merged into an individual', false);
    exception when others then
        ok('an organisation cannot be merged into an individual: ' || err(sqlerrm), sqlcode = -20713);
    end;
    xxcmp_party_pkg.merge_parties(l_dup, l_keep, 'Same company, registered twice.');
    commit;
    select * into l_p from xxcmp_parties where party_id = l_dup;
    ok('the duplicate is disabled and points to the kept party',
       l_p.enabled_flag = 'N' and l_p.merged_into_party_id = l_keep and l_p.merge_note is not null);
    select count(*) into l_cnt from xxcmp_cases where case_id = l_case and party_id = l_keep;
    ok('its closed case moved to the kept party', l_cnt = 1);
    select count(*) into l_cnt from xxcmp_cases where party_id = l_dup;
    select l_cnt + count(*) into l_cnt from xxcmp_requests where party_id = l_dup;
    ok('no case or request is left on the duplicate', l_cnt = 0);
    select count(*) into l_cnt from xxcmp_party_contacts where party_id = l_keep;
    select count(*) into l_txt from xxcmp_party_contacts where party_id = l_keep and primary_flag = 'Y';
    ok('contact persons moved (' || l_cnt || '), the kept party keeps one primary', l_cnt >= 2 and l_txt = '1');
    select count(*) into l_cnt from xxcmp_party_relationships where subject_party_id = l_new and object_party_id = l_keep;
    ok('ownership moved to the kept party', l_cnt = 1);
    select count(*) into l_cnt from xxcmp_party_relationships
     where l_keep in (subject_party_id, object_party_id) and l_dup in (subject_party_id, object_party_id);
    ok('the relationship between the two parties is removed', l_cnt = 0);
    select website into l_txt from xxcmp_parties where party_id = l_keep;
    ok('the kept party''s empty details are completed: ' || l_txt, l_txt = 'https://dup.example');
    ok('a merged party cannot be edited or merged again', xxcmp_party_pkg.is_enabled(l_dup) = 'N');
    apex_session.delete_session;
end;
/
exit
