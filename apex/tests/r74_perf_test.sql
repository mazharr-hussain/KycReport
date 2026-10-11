-- Release 74 R23 (KYC, run as XXCUS): performance best practice - every foreign key of the transaction tables has an
-- index (the history tables XXCMP_RFIS and XXCMP_CASE_DECISIONS are left as they are), the data security predicate of
-- the requests has its function-based index, the data security policy keeps a user's predicate for the request (the
-- same predicate, without re-reading the rules on every call) and still denies or allows the same rows.
set serveroutput on size unlimited feedback off
declare
    l_app    number;
    l_n      number;
    l_txt    varchar2(4000);
    l_pred   varchar2(32767);
    l_t0     pls_integer;
    l_cached pls_integer;
    l_fresh  pls_integer;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    select listagg(c.table_name || '.' || cc.column_name, ', ') within group (order by 1), count(*)
      into l_txt, l_n
      from user_constraints c
      join user_cons_columns cc on cc.constraint_name = c.constraint_name and cc.position = 1
     where c.constraint_type = 'R'
       and c.table_name in ('XXCMP_ALERTS', 'XXCMP_CASES', 'XXCMP_CASE_FUNDS', 'XXCMP_CASE_NOTES', 'XXCMP_DOC_VERIFICATIONS',
                            'XXCMP_FIU_REPORTS', 'XXCMP_REQUESTS', 'XXCMP_REQUEST_ANSWERS', 'XXCMP_SCREENINGS',
                            'XXCMP_UBO_DETERMINATIONS', 'XXCMP_PARTIES', 'XXCMP_CASE_RISK_SCORES',
                            'XXCMP_PARTY_ID_VERIFICATIONS', 'XXCMP_PARTY_REGISTRY_CHECKS')
       and not exists (select 1 from user_ind_columns ic
                        where ic.table_name = c.table_name and ic.column_name = cc.column_name and ic.column_position = 1);
    ok('every foreign key of the transaction tables is indexed' || nvl2(l_txt, ': missing ' || l_txt, null), l_n = 0);
    select count(*) into l_n from user_ind_expressions
     where index_name = 'XXCMP_REQUESTS_N4' and table_name = 'XXCMP_REQUESTS';
    ok('the requests have the function-based index of the data security predicate', l_n = 1);

    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'REQ1');
    xxfnd_vpd_pkg.clear_cache;
    l_pred := xxfnd_vpd_pkg.policy('XXCUS', 'XXCMP_REQUESTS');
    ok('a requester sees their own requests: ' || l_pred, l_pred like '%UPPER(REQUESTER_USER_NAME) IN (%''REQ1''%'
       or l_pred like '%upper(REQUESTER_USER_NAME) in (%''REQ1''%');
    l_t0 := dbms_utility.get_time;
    for i in 1 .. 2000 loop
        l_txt := xxfnd_vpd_pkg.policy('XXCUS', 'XXCMP_REQUESTS');
    end loop;
    l_cached := dbms_utility.get_time - l_t0;
    ok('the cached predicate is the same', l_txt = l_pred);
    l_t0 := dbms_utility.get_time;
    for i in 1 .. 2000 loop
        xxfnd_vpd_pkg.clear_cache;
        l_txt := xxfnd_vpd_pkg.policy('XXCUS', 'XXCMP_REQUESTS');
    end loop;
    l_fresh := dbms_utility.get_time - l_t0;
    ok('2000 policy calls: cached ' || l_cached || ' cs, re-read ' || l_fresh || ' cs', l_cached < l_fresh);
    select count(*) into l_n from xxcmp_requests where upper(requester_user_name) <> 'REQ1';
    ok('the requester still sees no one else''s request', l_n = 0);
    -- another user in another session gets their own predicate, not the cached one
    apex_session.create_session(l_app, 1, 'OFFICER1');
    l_txt := xxfnd_vpd_pkg.policy('XXCUS', 'XXCMP_REQUESTS');
    ok('another user gets their own predicate (' || nvl(l_txt, 'all rows') || ')', nvl(l_txt, '-') <> l_pred);
    apex_session.delete_session;
end;
/
exit
