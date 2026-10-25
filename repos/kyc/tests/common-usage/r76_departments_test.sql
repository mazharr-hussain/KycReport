-- Release 76 (KYC, run as XXCUS): requesting departments from data security. Needs db/admin/qd-users-and-roles.sql
-- (TEST1 with Requesting Entity - Finance and - Procurement). TEST1 may raise requests only for Finance and
-- Procurement (list and save check), sees only those departments' requests; a Level 1 approver (MGR1) any department.
set serveroutput on size unlimited feedback off
declare
    l_app number;
    l_req number;
    l_n   number;
    l_txt varchar2(4000);
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
        xxfnd_vpd_pkg.clear_cache;
    end;
    function save(p_dept varchar2) return varchar2 is
    begin
        l_req := null;
        xxcmp_request_pkg.save_request(l_req, 'NEW', null, 'ORGANIZATION', dbms_random.string('U', 16), 'AE',
                   'R76D' || to_char(systimestamp, 'HH24MISSFF3'), 'LLC', null,
                   'contact@example.com', '+971 4 000 0000', null, null, p_dept, 'Release 76 department test',
                   p_registration_type => 'COMMERCIAL_REGISTRATION', p_business_relationship => 'VENDOR',
                   p_draft => 'Y');
        return null;
    exception when others then
        return sqlcode || ' ' || regexp_substr(substr(sqlerrm, 12), '[^' || chr(10) || ']+');
    end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';

    session_as('TEST1');
    ok('TEST1 may raise requests for: ' || xxcmp_request_pkg.allowed_departments,
       xxcmp_request_pkg.allowed_departments in ('FINANCE,PROCUREMENT', 'PROCUREMENT,FINANCE'));
    l_txt := save('SALES');
    ok('a request for another department is refused: ' || l_txt, l_txt like '-20626 You cannot raise requests for Sales%');
    l_txt := save('FINANCE');
    ok('a request for Finance is saved' || nvl2(l_txt, ': ' || l_txt, null), l_txt is null and l_req is not null);
    select count(*) into l_n from xxcmp_requests where requesting_department not in ('FINANCE', 'PROCUREMENT');
    ok('TEST1 sees no request of another department (' || l_n || ')', l_n = 0);
    select count(*) into l_n from xxcmp_requests where request_id = l_req;
    ok('TEST1 sees the Finance request', l_n = 1);

    session_as('MGR1');
    ok('a Level 1 approver may raise requests for any department', xxcmp_request_pkg.allowed_departments is null);
    l_txt := save('SALES');
    ok('Level 1 raises a request on behalf of Sales' || nvl2(l_txt, ': ' || l_txt, null), l_txt is null);

    session_as('REQ1');
    ok('a Requester (own requests) keeps any department as before', xxcmp_request_pkg.allowed_departments is null);

    rollback;
    apex_session.delete_session;
end;
/
exit
