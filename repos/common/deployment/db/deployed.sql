--------------------------------------------------------------------------------
-- Run as the pipeline user: what the validation database holds (db/decide.py reads it in step 3.2b).
--   XXCI_DEPLOYED       the deployed version: its fingerprints (whole version, database scripts, structure, application
--                       without supporting objects), how it was verified (FULL = fresh install + upgrade test, PATCH =
--                       quick check only, DIRTY = a deploy started and did not finish) and the head commit last tested
--   XXCI_DEPLOYED_CODE  the code objects deployed (manifest key -> hash; APPLYING while a quick check runs them)
--   XXCI_PASSED         a check that passed for a version (ui, sert, dbsat -> its fingerprint): not run again on reuse
--   XXCI_FAILED_TESTS   the DB test files that failed in the last test run (run again by the next one)
-- Written by db/run.sh (record_deployed, mark_dirty, record_tests, record_passed) with small generated statements.
-- mode=get prints: DEPLOYED <fp> <db> <struct> <app> <verified> <tested head>, CODE <key> <hash>, PASSED <check>
-- <fingerprint>, FAILED <test file>. mode=init only makes the tables.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on size unlimited
create table if not exists xxci_deployed (
    app_code       varchar2(30) primary key,
    fingerprint    varchar2(64) not null,
    db_fingerprint varchar2(64),
    deployed_on    timestamp default systimestamp not null
);
-- columns that came after the table: added only when missing
declare
    procedure add_col(p_col varchar2, p_def varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from user_tab_columns where table_name = 'XXCI_DEPLOYED' and column_name = p_col;
        if l_n = 0 then
            execute immediate 'alter table xxci_deployed add (' || p_col || ' ' || p_def || ')';
        end if;
    end add_col;
begin
    add_col('DB_FINGERPRINT', 'varchar2(64)');
    add_col('STRUCT_FINGERPRINT', 'varchar2(64)');
    add_col('APP_FINGERPRINT', 'varchar2(64)');
    add_col('VERIFIED', 'varchar2(10)');
    add_col('TESTED_HEAD', 'varchar2(64)');
end;
/
create table if not exists xxci_deployed_code (
    code_key  varchar2(200) primary key,
    code_hash varchar2(64) not null
);
create table if not exists xxci_passed (
    check_name  varchar2(30) primary key,
    fingerprint varchar2(200) not null,
    passed_on   timestamp default systimestamp not null
);
create table if not exists xxci_failed_tests (
    test_file varchar2(400) primary key
);
begin
    if '&mode' = 'get' then
        for r in (select fingerprint, db_fingerprint, struct_fingerprint, app_fingerprint, verified, tested_head
                    from xxci_deployed where app_code = 'COMMON') loop
            dbms_output.put_line('DEPLOYED ' || nvl(r.fingerprint, '-') || ' ' || nvl(r.db_fingerprint, '-') || ' '
                || nvl(r.struct_fingerprint, '-') || ' ' || nvl(r.app_fingerprint, '-') || ' '
                || nvl(r.verified, 'FULL') || ' ' || nvl(r.tested_head, '-'));
        end loop;
        for r in (select code_key, code_hash from xxci_deployed_code order by code_key) loop
            dbms_output.put_line('CODE ' || r.code_key || ' ' || r.code_hash);
        end loop;
        for r in (select check_name, fingerprint from xxci_passed order by check_name) loop
            dbms_output.put_line('PASSED ' || r.check_name || ' ' || r.fingerprint);
        end loop;
        for r in (select test_file from xxci_failed_tests order by test_file) loop
            dbms_output.put_line('FAILED ' || r.test_file);
        end loop;
    end if;
end;
/
