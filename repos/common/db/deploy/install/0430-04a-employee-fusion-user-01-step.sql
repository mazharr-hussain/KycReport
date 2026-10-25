-- 04a Employees: Fusion user account (release 37). USER_NAME = the Fusion / identity-domain user name used by single
-- sign-on, EMAIL_ADDRESS = the work e-mail, FUSION_USER_ID = the Fusion user account (HCM userAccounts UserId).
-- Idempotent.

declare
    l_count pls_integer;
begin
    select count(*) into l_count from user_tab_columns
     where table_name = 'XXHR_EMPLOYEES' and column_name = 'FUSION_USER_ID';
    if l_count = 0 then
        execute immediate 'alter table xxhr_employees add (fusion_user_id varchar2(64))';
    end if;
end;
/
comment on column xxhr_employees.user_name is 'Sign-in name: the Fusion / identity-domain user name (upper case); the work e-mail until the HCM sync finds a user account.';
comment on column xxhr_employees.fusion_user_id is 'Fusion user account id (HCM userAccounts UserId), set by the HCM sync.';
