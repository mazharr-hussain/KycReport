-- COMMON 111: menu group page links, RFI lookups owned by COMMON, KYC_USER retired. Run as XXFUSION in an APEX
-- session of a COMMON administrator (COMMON application, any page). Everything is rolled back.
set serveroutput on size unlimited feedback off
declare
    l_n   pls_integer;
    l_url varchar2(4000);
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    -- I-059: the APEX session of the tests' administrator ADMIN (tests/setup/03_common_test_fixture.sql)
    apex_util.set_workspace('XXCUS');
    apex_session.create_session(p_app_id => 135, p_page_id => 1, p_username => 'ADMIN');
    -- a menu group opens page 100 for its group; without a code it only expands
    l_url := xxfnd_application_pkg.menu_url('COMMON', 'FOLDER', null, null, 'M_PLATFORM');
    ok('group link opens page 100: ' || l_url, l_url like '%100%' and upper(l_url) like '%M_PLATFORM%');
    ok('group without code has no link', xxfnd_application_pkg.menu_url('COMMON', 'FOLDER', null, null) is null);
    -- the group page lists the group's entries the user sees
    select count(*) into l_n from xxfnd_nav_menu_v where target_type = 'FOLDER' and target is not null;
    ok('menu groups have a link (' || l_n || ')', l_n > 0);
    select count(*) into l_n from xxfnd_nav_menu_v c
     where c.parent_code = (select min(entry_code) from xxfnd_nav_menu_v where target_type = 'FOLDER');
    ok('a group has entries for its page (' || l_n || ')', l_n > 0);
    -- RFI lookups are shared COMMON types with the values XXFND_RFIS allows
    select count(*) into l_n from xxfnd_lookup_types
     where lookup_type in ('RFI_STATUS', 'RFI_RECIPIENT_TYPE', 'RFI_CATEGORY') and application_code is null;
    ok('RFI lookup types belong to COMMON', l_n = 3);
    select count(*) into l_n from xxfnd_lookup_values
     where lookup_type = 'RFI_STATUS'
       and lookup_code in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING', 'RESPONDED', 'ON_HOLD_INVESTIGATION',
                           'RESOLVED', 'REJECTED_RETURNED', 'CANCELLED');
    ok('every RFI status has a name', l_n = 7);
    select count(*) into l_n from xxfnd_lookup_values
     where lookup_type = 'RFI_RECIPIENT_TYPE' and lookup_code in ('USER', 'EXTERNAL');
    ok('both recipient types have a name', l_n = 2);
    -- KYC_USER and ADMIN_APP are no longer schemes
    ok('KYC_USER retired', not xxfnd_user_pkg.authorized('KYC_USER'));
    ok('ADMIN_APP retired', not xxfnd_user_pkg.authorized('ADMIN_APP'));
    rollback;
end;
/
