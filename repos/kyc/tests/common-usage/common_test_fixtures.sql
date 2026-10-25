-- Release 93 (KYC tests): test-only states of COMMON data that COMMON has no routine for yet (COMMON 88 and later
-- refuse direct writes from applications). Run as XXFUSION on the local test database only, before the KYC tests
-- (apex/tests/run_all.sh does it). It is NOT part of COMMON: COMMON's install never creates it. The missing routines
-- are listed for the COMMON team in apex/COMMON-ISSUES.md (C13 delegations, C14 enabling rules and role grants);
-- when COMMON has them, the tests call them and this file goes.
create or replace package xxfnd_test_fixture_pkg authid definer as
    -- delegations (Workflow Setup > Delegations)
    procedure add_delegation(p_delegator in varchar2, p_delegate in varchar2, p_start in date, p_end in date,
                             p_reason in varchar2);
    procedure clear_delegations;
    -- switch an application's approval rules of a type on / off (Approval Setup)
    procedure set_rules_enabled(p_type in varchar2, p_enabled in varchar2);
    -- switch every open grant of a role on / off (Users & Access)
    procedure set_role_enabled(p_role_code in varchar2, p_enabled in varchar2);
end xxfnd_test_fixture_pkg;
/
create or replace package body xxfnd_test_fixture_pkg as
    procedure add_delegation(p_delegator in varchar2, p_delegate in varchar2, p_start in date, p_end in date,
                             p_reason in varchar2) is
    begin
        insert into xxfnd_wf_delegations (delegator_user_name, delegate_user_name, start_date, end_date, reason)
        values (upper(p_delegator), upper(p_delegate), p_start, p_end, p_reason);
    end add_delegation;

    procedure clear_delegations is
    begin
        delete from xxfnd_wf_delegations;
    end clear_delegations;

    procedure set_rules_enabled(p_type in varchar2, p_enabled in varchar2) is
    begin
        update xxfnd_approval_rules set enabled_flag = p_enabled
         where approval_type_code = upper(p_type) and enabled_flag <> p_enabled;
    end set_rules_enabled;

    procedure set_role_enabled(p_role_code in varchar2, p_enabled in varchar2) is
    begin
        update xxfnd_user_roles set enabled_flag = p_enabled
         where role_code = upper(p_role_code) and end_date_active is null and enabled_flag <> p_enabled;
    end set_role_enabled;
end xxfnd_test_fixture_pkg;
/
grant execute on xxfnd_test_fixture_pkg to xxcus;
