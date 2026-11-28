--------------------------------------------------------------------------------
-- Run as the pipeline user: what the validation database holds (db/decide.py reads it in step 3.2b).
--   XXCI_DEPLOYED       the deployed version: its fingerprints (whole version, database scripts, structure, application
--                       without supporting objects), how it was verified (FULL = fresh install + upgrade test, PATCH =
--                       quick check only, DIRTY = a deploy started and did not finish) and the head commit last tested
--   XXCI_DEPLOYED_CODE  the code objects deployed (manifest key -> hash; APPLYING while a quick check runs them)
--   XXCI_PASSED         a check that passed for a version (ui, sert, dbsat -> its fingerprint): not run again on reuse;
--                       fresh -> the fresh install (job 5) passed for that version: a restart may skip job 5
--   XXCI_FAILED_TESTS   the DB test files that failed in the last test run (run again by the next one)
--   XXCI_APP_OBJECTS    the application's own objects (db/app_objects.py) every deploy since the last remove made:
--                       5.1 / 6.1 remove only these and this version's (I-077 - never other objects of the schema)
--   XXCI_UPGRADE_SNAPSHOT the application's tables before the upgrade (6.4): a run that resumes after the upgrade
--                       compares with it (6.6) - no backup schema (I-076)
--   XXCI_FRESH_SCHEMA   the structure of the last fresh install that passed (5.5; XXCI_PASSED 'fresh' holds its
--                       fingerprint) - the upgrade test compares the upgraded database with it (6.8)
-- One record per application (I-106): &t is the table prefix (xxci for COMMON, xxci_<app> for another application: the
-- tables below read xxci_deployed ... for COMMON), &app_code its key in XXCI_DEPLOYED.
-- Written by db/run.sh (record_deployed, mark_dirty, record_tests, record_passed) with small generated statements.
-- mode=get prints: DEPLOYED <fp> <db> <struct> <app> <verified> <tested head>, CODE <key> <hash>, PASSED <check>
-- <fingerprint>, FAILED <test file>. mode=init only makes the tables.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on size unlimited
create table if not exists &t._deployed (
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
        select count(*) into l_n from user_tab_columns where table_name = upper('&t._deployed') and column_name = p_col;
        if l_n = 0 then
            execute immediate 'alter table &t._deployed add (' || p_col || ' ' || p_def || ')';
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
create table if not exists &t._deployed_code (
    code_key  varchar2(200) primary key,
    code_hash varchar2(64) not null
);
create table if not exists &t._passed (
    check_name  varchar2(30) primary key,
    fingerprint varchar2(200) not null,
    passed_on   timestamp default systimestamp not null
);
create table if not exists &t._failed_tests (
    test_file varchar2(400) primary key
);
create table if not exists &t._app_objects (
    obj_type varchar2(30),
    obj_name varchar2(128),
    constraint &t._app_objects_pk primary key (obj_type, obj_name)
);
create table if not exists &t._upgrade_snapshot (
    line_no number primary key,
    line    varchar2(4000) not null
);
create table if not exists &t._fresh_schema (
    line_no number primary key,
    line    varchar2(4000) not null
);
begin
    if '&mode' = 'get' then
        for r in (select fingerprint, db_fingerprint, struct_fingerprint, app_fingerprint, verified, tested_head
                    from &t._deployed where app_code = '&app_code') loop
            dbms_output.put_line('DEPLOYED ' || nvl(r.fingerprint, '-') || ' ' || nvl(r.db_fingerprint, '-') || ' '
                || nvl(r.struct_fingerprint, '-') || ' ' || nvl(r.app_fingerprint, '-') || ' '
                || nvl(r.verified, 'FULL') || ' ' || nvl(r.tested_head, '-'));
        end loop;
        for r in (select code_key, code_hash from &t._deployed_code order by code_key) loop
            dbms_output.put_line('CODE ' || r.code_key || ' ' || r.code_hash);
        end loop;
        for r in (select check_name, fingerprint from &t._passed order by check_name) loop
            dbms_output.put_line('PASSED ' || r.check_name || ' ' || r.fingerprint);
        end loop;
        for r in (select test_file from &t._failed_tests order by test_file) loop
            dbms_output.put_line('FAILED ' || r.test_file);
        end loop;
    end if;
end;
/
