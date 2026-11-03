--------------------------------------------------------------------------------
-- Steps 3.2b / 4.7 / 5.8, run as the pipeline user: the version the validation database holds - the fingerprint of
-- the whole version (application + database scripts) and of its database scripts alone. 4.7 / 5.8 record them once
-- the version passed its deploy; 3.2b reads them:
--   same version             -> jobs 4-5 are skipped (a push of tests, docs or the pipeline only)
--   same database scripts    -> job 4 replaces the APEX application only (schema and data kept), job 5 is skipped
--   other database scripts   -> full fresh install (and the upgrade test when they differ from the base)
-- Substitution variables: mode (get / set), fingerprint, db_fingerprint.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
create table if not exists xxci_deployed (
    app_code       varchar2(30) primary key,
    fingerprint    varchar2(64) not null,
    db_fingerprint varchar2(64),
    deployed_on    timestamp default systimestamp not null
);
-- the column came after the table (a table made before it has no DB_FINGERPRINT): added only when missing
declare
    l_n pls_integer;
begin
    select count(*) into l_n from user_tab_columns where table_name = 'XXCI_DEPLOYED' and column_name = 'DB_FINGERPRINT';
    if l_n = 0 then
        execute immediate 'alter table xxci_deployed add (db_fingerprint varchar2(64))';
    end if;
end;
/
declare
    l_fp  xxci_deployed.fingerprint%type;
    l_db  xxci_deployed.db_fingerprint%type;
begin
    if '&mode' = 'set' then
        merge into xxci_deployed t using (select 'COMMON' app_code from dual) s on (t.app_code = s.app_code)
         when matched then update set t.fingerprint = '&fingerprint', t.db_fingerprint = '&db_fingerprint',
                                      t.deployed_on = systimestamp
         when not matched then insert (app_code, fingerprint, db_fingerprint)
                               values ('COMMON', '&fingerprint', '&db_fingerprint');
        commit;
        dbms_output.put_line('DEPLOYED &fingerprint &db_fingerprint');
    else
        select max(fingerprint), max(db_fingerprint) into l_fp, l_db from xxci_deployed where app_code = 'COMMON';
        dbms_output.put_line('DEPLOYED ' || nvl(l_fp, '-') || ' ' || nvl(l_db, '-'));
    end if;
end;
/
