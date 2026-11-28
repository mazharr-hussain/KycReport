--------------------------------------------------------------------------------
-- Step 7.4, run as ADMIN: APEX-SERT security evaluation of the application (installed by step 3.4), in the
-- foreground, with the SERT-SECURITY rules of the database's APEX version; writes every rule that did not pass
-- (CSV) and prints the counts by severity.
-- Substitution variables: app_id, out (CSV file).
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
prompt SERT-START evaluation of application &app_id
variable eval_id number
-- SERT's security rules (rule set SERT-SECURITY) exist per APEX version (the evaluation picks the rule set of the
-- database's own APEX version). APEX-SERT's latest release has them for 24.1, 24.2 and 25.1. For an APEX version it
-- has none for (26.1 today) SERT's own upgrade path is used (SERT_CORE.RULES_PKG.UPGRADE_RULES, the one its installer
-- runs when a release ships rules for the new version): the newest older rule set and its rules are copied to this
-- version, exceptions kept, the older set deactivated; a SERT-NOTE says so. When that is not possible, the evaluation is
-- reported (SERT-SKIP) and nothing is evaluated - a tool limit, not a finding (db/run.sh turns it into a notice).
declare
    l_n   pls_integer;
    l_v   number;
    l_src number;
begin
    select max(apex_version) into l_v from sert_core.apex_version_v;
    select count(*) into l_n from sert_core.rule_sets where rule_set_key = 'SERT-SECURITY' and apex_version = l_v;
    if l_n = 0 then
        select max(apex_version) into l_src from sert_core.rule_sets where rule_set_key = 'SERT-SECURITY' and apex_version < l_v;
        if l_src is not null then
            begin
                -- UPGRADE_RULES reads the previous version from this preference and sets it to the new one
                update sert_core.prefs set pref_value = trim(to_char(l_src, '99.9')) where pref_key = 'SERT_APEX_VERSION';
                sert_core.rules_pkg.upgrade_rules;
                commit;
                dbms_output.put_line('SERT-NOTE APEX-SERT has no SERT-SECURITY rules for APEX ' || to_char(l_v, 'fm99.9')
                    || ': its rules for APEX ' || to_char(l_src, 'fm99.9') || ' (the newest it has) were carried forward');
            exception
                when others then
                    rollback;
                    dbms_output.put_line('SERT-SKIP APEX-SERT has no SERT-SECURITY rules for APEX ' || to_char(l_v, 'fm99.9')
                        || ' and its rules for APEX ' || to_char(l_src, 'fm99.9') || ' could not be carried forward: '
                        || substr(sqlerrm, 1, 300));
            end;
        end if;
        select count(*) into l_n from sert_core.rule_sets where rule_set_key = 'SERT-SECURITY' and apex_version = l_v;
    end if;
    if l_n = 0 then
        select count(*) into l_n from sert_core.rule_sets where rule_set_key = 'SERT-SECURITY';
        dbms_output.put_line('SERT-SKIP APEX-SERT has no SERT-SECURITY rules for APEX ' || to_char(l_v, 'fm99.9')
            || ' (it has rules for ' || l_n || ' other APEX versions) - not evaluated');
    else
        sert_core.eval_pkg.eval(p_application_id => &app_id, p_rule_set_key => 'SERT-SECURITY', p_eval_by => 'COMMON PIPELINE',
                                p_run_in_background => 'N', p_eval_id_out => :eval_id);
    end if;
end;
/
set heading off
set pagesize 0
set sqlformat default
-- the counts and diagnostics first, with the terminal output on (the CSV below needs it off)
select 'SERT-DEBUG eval_id=' || nvl(to_char(:eval_id), 'none') || ' rows in the results view: '
       || (select count(*) from sert_core.eval_results_pub_v where eval_id = :eval_id)
       || ', all evaluations: ' || (select count(*) from sert_core.eval_results_pub_v)
       || ', rule sets: ' || (select count(*) from sert_core.rule_sets where rule_set_key = 'SERT-SECURITY')
  from dual;
-- where did the evaluation's data go: the rows per SERT_CORE table that has an EVAL_ID
declare
    l_n pls_integer;
begin
    for t in (select table_name from all_tab_columns where owner = 'SERT_CORE' and column_name = 'EVAL_ID'
                 and table_name in (select table_name from all_tables where owner = 'SERT_CORE') order by table_name) loop
        execute immediate 'select count(*) from sert_core.' || t.table_name || ' where eval_id = :1' into l_n using :eval_id;
        dbms_output.put_line('SERT-DEBUG ' || t.table_name || ' rows for this evaluation: ' || l_n);
    end loop;
end;
/
select 'SERT ' || nvl(rule_severity_name, '-') || ' ' || result || ': ' || count(*)
  from sert_core.eval_results_pub_v
 where eval_id = :eval_id
 group by rule_severity_name, result
 order by 1;
-- every rule that did not pass, as CSV (the report artifact)
set heading on
set sqlformat csv
set termout off
spool &out
select rule_severity_name as severity, rule_name as rule, result, full_page_name as page, component_name, item_name,
       current_value, valid_values, reason
  from sert_core.eval_results_pub_v
 where eval_id = :eval_id and result not in ('PASS', 'APPROVED')
 order by rule_severity_id, rule_name, page_id;
spool off
set termout on
set sqlformat default
set heading off
