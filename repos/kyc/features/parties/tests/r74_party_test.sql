-- Release 74 party component (KYC, run as XXCUS): party matching and directory in the party package, the party card
-- as data (card_json), identity and registry checks (rules, merge). Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_org   number;
    l_per   number;
    l_dup   number;
    l_n     number;
    l_json  clob;
    l_err   varchar2(4000);
    l_id    number;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'OFFICER1');
    xxfnd_util_pkg.set_install_mode(true);
    insert into xxcmp_parties (party_type, party_name, jurisdiction, registration_number, party_status)
    values ('ORGANIZATION', 'R74 Party Test Trading LLC', 'AE', 'R74-' || to_char(systimestamp, 'FF6'), 'APPROVED')
    returning party_id into l_org;
    insert into xxcmp_parties (party_type, party_name, jurisdiction, registration_number, party_status)
    values ('PERSON', 'R74 Test Person', 'AE', 'P' || to_char(systimestamp, 'FF6'), 'APPROVED')
    returning party_id into l_per;
    insert into xxcmp_parties (party_type, party_name, jurisdiction, party_status)
    values ('ORGANIZATION', 'R74 Party Test Trading', 'AE', 'PENDING')
    returning party_id into l_dup;
    xxfnd_util_pkg.set_install_mode(false);

    -- matching moved to the party package
    ok('name similarity (party package) ' || xxcmp_party_pkg.name_similarity('R74 Party Test Trading LLC', 'R74 Party Test Trading'),
       xxcmp_party_pkg.name_similarity('R74 Party Test Trading LLC', 'R74 Party Test Trading') >= 95);
    -- release 90: PARTY_CANDIDATE_COUNT is private; the candidates JSON gives the same count
    l_n := json_array_t.parse(xxcmp_party_pkg.party_candidates_json('ORGANIZATION', 'R74 Party Test Trading', null, null, 'AE', l_dup)).get_size;
    ok('candidates for the duplicate: ' || l_n, l_n >= 1);
    select count(*) into l_n
      from json_table(xxcmp_party_pkg.party_directory_json('ORGANIZATION'), '$[*]' columns (party_id number path '$.party_id'))
     where party_id = l_org;
    ok('directory lists the approved party', l_n = 1);

    -- the party card as data
    l_json := xxcmp_party_pkg.card_json(l_org);
    select count(*) into l_n from json_table(l_json, '$[*]' columns (label varchar2(100) path '$.label', tone varchar2(30) path '$.tone'))
     where label = 'Status' and tone is not null;
    ok('card_json: fields with the party status', l_n = 1 and dbms_lob.instr(l_json, '"Name"') > 0);
    select count(*) into l_n from json_table(xxcmp_party_pkg.card_json(l_org, p_show_status => 'N'), '$[*]' columns (label varchar2(100) path '$.label'))
     where label in ('Status', 'Next KYC Date');
    ok('card_json without status: no status or KYC dates', l_n = 0);

    -- identity checks: individuals only, no verified expired document
    ok('ID check refused for an organisation', xxcmp_party_pkg.id_verification_error(l_org, 'X1', null, null, 'VERIFIED') is not null);
    l_err := xxcmp_party_pkg.id_verification_error(l_per, 'X1', date '2015-01-01', date '2020-01-01', 'VERIFIED');
    ok('expired document cannot be verified: ' || l_err, l_err is not null);
    ok('valid ID check accepted', xxcmp_party_pkg.id_verification_error(l_per, 'X1', date '2020-01-01', trunc(sysdate) + 365, 'VERIFIED') is null);
    insert into xxcmp_party_id_verifications (party_id, document_type, document_number, verification_method, verification_result, verified_by)
    values (l_per, 'PASSPORT', 'X1', 'ORIGINAL_SEEN', 'VERIFIED', 'OFFICER1');

    -- registry checks: organisations only; a provider row needs its provider; a person's change is marked
    ok('registry check refused for an individual', xxcmp_party_pkg.registry_check_error(l_per, 'MANUAL', null, 'MATCH') is not null);
    ok('provider check needs the provider', xxcmp_party_pkg.registry_check_error(l_org, 'API', null, 'MATCH') is not null);
    ok('manual registry check accepted', xxcmp_party_pkg.registry_check_error(l_org, 'MANUAL', null, 'MATCH') is null);
    insert into xxcmp_party_registry_checks (party_id, registry_name, check_result, checked_by)
    values (l_org, 'Test registry', 'MATCH', 'OFFICER1') returning registry_check_id into l_id;
    xxcmp_party_pkg.registry_check_saved(l_id);
    select count(*) into l_n from xxcmp_party_registry_checks where registry_check_id = l_id and changed_by_person_flag = 'N';
    ok('a manual check is not marked as changed by a person', l_n = 1);
    -- release 91: REVIEW_REGISTRY_CHECK is removed (no screen called it)
    ok('Compliance may record a check on the party', xxcmp_party_pkg.can_record_verification(l_org) = 'Y');

    -- merge: the duplicate's checks move to the kept party
    insert into xxcmp_party_registry_checks (party_id, registry_name, check_result, checked_by)
    values (l_dup, 'Dup registry', 'NOT_FOUND', 'OFFICER1');
    apex_session.create_session(l_app, 1, 'MGR1');
    begin
        xxcmp_party_pkg.merge_parties(l_dup, l_org, 'R74 test');
        select count(*) into l_n from xxcmp_party_registry_checks where party_id = l_org;
        ok('merge moves the registry checks to the kept party (' || l_n || ')', l_n = 2);
    exception
        when others then
            ok('merge (needs Parties Manage for MGR1): ' || sqlerrm, false);
    end;
    rollback;
    apex_session.delete_session;
end;
/
exit
