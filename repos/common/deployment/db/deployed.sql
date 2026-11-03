--------------------------------------------------------------------------------
-- Steps 3.2b / 5.8, run as the pipeline user: the fingerprint of the application version the validation database
-- holds after a passed upgrade test (5.8 records it; 3.2b reads it). A push whose built application and database
-- scripts have the same fingerprint (a change to tests, docs or the pipeline only) skips jobs 4-5: the database
-- already holds exactly this version. Substitution variables: mode (get / set), fingerprint.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
create table if not exists xxci_deployed (
    app_code    varchar2(30) primary key,
    fingerprint varchar2(64) not null,
    deployed_on timestamp default systimestamp not null
);
declare
    l_fp xxci_deployed.fingerprint%type;
begin
    if '&mode' = 'set' then
        merge into xxci_deployed t using (select 'COMMON' app_code from dual) s on (t.app_code = s.app_code)
         when matched then update set t.fingerprint = '&fingerprint', t.deployed_on = systimestamp
         when not matched then insert (app_code, fingerprint) values ('COMMON', '&fingerprint');
        commit;
        dbms_output.put_line('DEPLOYED &fingerprint');
    else
        select max(fingerprint) into l_fp from xxci_deployed where app_code = 'COMMON';
        dbms_output.put_line('DEPLOYED ' || nvl(l_fp, '-'));
    end if;
end;
/
