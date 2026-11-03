--------------------------------------------------------------------------------
-- Step 6.4, run as ADMIN: APEX-SERT security evaluation of the application (installed by step 3.4), in the
-- foreground; writes every rule that did not pass (CSV) and prints the counts by severity.
-- Substitution variables: app_id, out (CSV file).
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
variable eval_id number
begin
    sert_core.eval_pkg.eval(p_application_id => &app_id, p_eval_by => 'COMMON PIPELINE', p_run_in_background => 'N',
                            p_eval_id_out => :eval_id);
end;
/
set heading on pagesize 0 termout off
set sqlformat csv
spool &out
select rule_severity_name as severity, rule_name as rule, result, full_page_name as page, component_name, item_name,
       current_value, valid_values, reason
  from sert_core.eval_results_pub_v
 where eval_id = :eval_id and result not in ('PASS', 'APPROVED')
 order by rule_severity_id, rule_name, page_id;
spool off
set termout on sqlformat default heading off
select 'SERT ' || nvl(rule_severity_name, '-') || ' ' || result || ': ' || count(*)
  from sert_core.eval_results_pub_v
 where eval_id = :eval_id
 group by rule_severity_name, result
 order by 1;
