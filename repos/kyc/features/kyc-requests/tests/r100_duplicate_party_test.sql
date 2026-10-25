-- KYC 100 (requester area): a counterparty with the registration type, registration number and country of another
-- party is not created again - the request form asks Use the existing party Yes (the request links it) / No (change
-- the details); a draft is checked too; the registration type is required. Everything is rolled back.
-- Needs security_test.sql (REQ1).
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_tag   varchar2(20) := dbms_random.string('U', 10);
    l_a     number;
    l_b     number;
    l_party number;
    l_txt   varchar2(4000);
    l_r     xxcmp_requests%rowtype;

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function rule(p_request_id number, p_number varchar2, p_use varchar2 default null) return varchar2 is
    begin
        return xxcmp_request_pkg.request_error(p_request_id, 'NEW', null, 'ORGANIZATION', 'R100 B ' || l_tag, 'AE',
                                               p_number, 'PRIVATE_COMPANY', null, null, null, 'Why',
                                               p_registration_type => 'COMMERCIAL_REGISTRATION',
                                               p_business_relationship => 'VENDOR', p_use_existing => p_use);
    end rule;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 201, 'REQ1');

    -- request A creates the party (Pending)
    xxcmp_request_pkg.save_request(l_a, 'NEW', null, 'ORGANIZATION', 'R100 A ' || l_tag, 'AE', 'CR-' || l_tag,
                                   'PRIVATE_COMPANY', null, null, null, null, null, null, null, p_draft => 'Y',
                                   p_registration_type => 'COMMERCIAL_REGISTRATION');
    select party_id into l_party from xxcmp_requests where request_id = l_a;
    ok('request A creates its Pending party', l_party is not null);
    ok('the request''s own party is not its duplicate',
       xxcmp_request_pkg.duplicate_party_id(l_a, 'ORGANIZATION', 'CR-' || l_tag, 'AE', 'COMMERCIAL_REGISTRATION') is null);

    -- request B: the same type, number (other punctuation) and country
    ok('duplicate found (spaces and punctuation ignored)',
       xxcmp_request_pkg.duplicate_party_id(null, 'ORGANIZATION', 'cr ' || lower(l_tag), 'AE', 'COMMERCIAL_REGISTRATION') = l_party);
    l_txt := rule(null, 'CR-' || l_tag);
    ok('unanswered: asks to use the existing party: ' || l_txt, l_txt like 'Party % already has this registration type, registration number and country. Use the existing party?%');
    l_txt := rule(null, 'CR-' || l_tag, 'N');
    ok('No: asks to change the details: ' || l_txt, l_txt like 'Change the registration type, registration number or country%');
    l_txt := xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'R100 B ' || l_tag, 'AE', 'CR-' || l_tag,
                                             null, null, null, null, null, p_draft => 'Y',
                                             p_registration_type => 'COMMERCIAL_REGISTRATION');
    ok('a draft is checked too: ' || l_txt, l_txt like 'Party % Use the existing party?%');
    ok('another registration type is another registration',
       xxcmp_request_pkg.duplicate_party_id(null, 'ORGANIZATION', 'CR-' || l_tag, 'AE', 'TRADE_LICENCE') is null);
    ok('another country is another registration',
       xxcmp_request_pkg.duplicate_party_id(null, 'ORGANIZATION', 'CR-' || l_tag, 'QA', 'COMMERCIAL_REGISTRATION') is null);
    l_txt := xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'R100 B ' || l_tag, 'AE', 'CR-' || l_tag,
                                             null, null, null, null, 'Why', p_registration_type => 'COMMERCIAL_REGISTRATION',
                                             p_use_existing => 'Y');
    ok('Yes: the business relationship is still asked: ' || l_txt, l_txt like 'Choose the business relationship%');
    ok('Yes: accepted', rule(null, 'CR-' || l_tag, 'Y') is null);

    -- Yes: request B links the existing party, no new party
    xxcmp_request_pkg.save_request(l_b, 'NEW', null, 'ORGANIZATION', 'R100 B ' || l_tag, 'AE', 'CR-' || l_tag,
                                   'PRIVATE_COMPANY', null, null, null, null, null, null, 'Why',
                                   p_registration_type => 'COMMERCIAL_REGISTRATION', p_business_relationship => 'VENDOR',
                                   p_use_existing => 'Y');
    select * into l_r from xxcmp_requests where request_id = l_b;
    ok('Yes: request B uses the existing (Pending) party: ' || l_r.party_selection,
       l_r.party_id = l_party and l_r.party_selection = 'EXISTING' and l_r.match_status = 'SELECTED');
    ok('Yes: no second party', xxcmp_party_pkg.party_status(l_party) = 'PENDING');
    -- saving B again changes nothing
    xxcmp_request_pkg.save_request(l_b, 'EXISTING', l_party, null, null, null, null, null, null, null, null, null, null,
                                   null, 'Why', p_business_relationship => 'VENDOR');
    select * into l_r from xxcmp_requests where request_id = l_b;
    ok('saving again keeps the party', l_r.party_id = l_party);
    ok('the requester sees the linked party', xxcmp_party_pkg.can_view(l_party, l_b) = 'Y');

    -- the registration type is required on the request form
    ok('the registration type is required',
       xxcmp_party_pkg.party_error(null, 'ORGANIZATION', 'R100 C ' || l_tag, 'AE', 'X-' || l_tag, 'PRIVATE_COMPANY', null,
                                   null, null, p_request_form => 'Y') = 'Choose the registration type of the registration number.');
    rollback;
    apex_session.delete_session;
exception
    when others then
        rollback;
        dbms_output.put_line('FAIL ' || sqlerrm);
end;
/
