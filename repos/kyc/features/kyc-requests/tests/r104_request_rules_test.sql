-- KYC 104 (Create Request: Counterparty, Questions, Review and Submit): the business relationship is required whatever
-- the risk screening finds; the business justification is optional. Everything is rolled back.
-- Needs security_test.sql (REQ1).
set serveroutput on size unlimited feedback off
declare
    l_app number;
    l_tag varchar2(20) := dbms_random.string('U', 10);
    l_txt varchar2(4000);

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function rule(p_relationship varchar2, p_justification varchar2) return varchar2 is
    begin
        return xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'R104 ' || l_tag, 'AE', 'CR-' || l_tag,
                                               'PRIVATE_COMPANY', null, null, null, p_justification,
                                               p_registration_type => 'COMMERCIAL_REGISTRATION',
                                               p_business_relationship => p_relationship);
    end rule;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 201, 'REQ1');
    l_txt := rule(null, 'Why');
    ok('the business relationship is required: ' || l_txt, l_txt like 'Choose the business relationship%');
    ok('the business justification is optional', rule('VENDOR', null) is null);
    ok('a draft needs no relationship', xxcmp_request_pkg.request_error(null, 'NEW', null, 'ORGANIZATION', 'R104 ' || l_tag,
           'AE', 'CR-' || l_tag, 'PRIVATE_COMPANY', null, null, null, null, p_draft => 'Y',
           p_registration_type => 'COMMERCIAL_REGISTRATION') is null);
    rollback;
    apex_session.delete_session;
exception
    when others then
        rollback;
        dbms_output.put_line('FAIL ' || sqlerrm);
end;
/
