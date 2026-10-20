-- Release 76 (T-01): the test users of every database and browser test, in one place (idempotent). Run it once on a new
-- database before any test; security_test.sql and workflow_test.sql call it too.
--   REQ1, REQ2 Requester · OFFICER1 Compliance Officer · MGR1 Compliance Manager · HOC1 Head of Compliance
--   (employees + role grants + APEX accounts, password KycTest#2026)
declare
    procedure u(p_user varchar2, p_role varchar2) is
    begin
        -- release 93: through COMMON's routine (COMMON 88 and later refuse direct writes): the LOCAL employee and the role
        xxfnd_user_pkg.bootstrap_admin(p_user, initcap(p_user), lower(p_user) || '@example.com', p_role);
        apex_util.set_workspace('XXCUS');
        if apex_util.find_security_group_id('XXCUS') is not null and apex_util.get_user_id(p_user) is null then
            apex_util.create_user(p_user_name => p_user, p_web_password => 'KycTest#2026', p_change_password_on_first_use => 'N');
        end if;
    end;
begin
    u('REQ1', 'REQUESTER');
    u('REQ2', 'REQUESTER');
    u('OFFICER1', 'COMPLIANCE_OFFICER');
    u('MGR1', 'COMPLIANCE_MANAGER');
    u('HOC1', 'HEAD_OF_COMPLIANCE');
    commit;
end;
/
