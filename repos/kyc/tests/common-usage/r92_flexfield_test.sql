-- Release 92 (COMMON UI issues 6, 7): context rule, segment API name, sequence default, lookup validation.
-- Run as XXFUSION on a test database (it adds and removes its own test rows).
set serveroutput on
declare
    l_pass pls_integer := 0; l_fail pls_integer := 0;
    l_v    varchar2(4000);
    l_lk   varchar2(30);
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        if p_cond then l_pass := l_pass + 1; dbms_output.put_line('PASS ' || p_label);
        else l_fail := l_fail + 1; dbms_output.put_line('FAIL ' || p_label); end if;
    end;
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- migrated rules
    select context_rule_type into l_v from xxfnd_df_flexfields where descriptive_flexfield_code = 'XXCMP_PARTIES_DFF';
    ok('existing flexfield with a reference column became ATTRIBUTE', l_v = 'ATTRIBUTE');
    -- trigger: rule GLOBAL clears the reference column; FUNCTION needs a function
    update xxfnd_df_flexfields set context_rule_type = 'GLOBAL' where descriptive_flexfield_code = 'XXCMP_PARTY_REL_DFF';
    select nvl(context_reference_column, '-') || context_user_selectable_flag into l_v
      from xxfnd_df_flexfields where descriptive_flexfield_code = 'XXCMP_PARTY_REL_DFF';
    ok('GLOBAL: no reference column, not user-chosen', l_v = '-N');
    begin
        update xxfnd_df_flexfields set context_rule_type = 'FUNCTION' where descriptive_flexfield_code = 'XXCMP_PARTY_REL_DFF';
        ok('FUNCTION without a function is refused', false);
    exception when others then ok('FUNCTION without a function is refused', sqlcode = -20215);
    end;
    update xxfnd_df_flexfields set context_rule_type = 'USER' where descriptive_flexfield_code = 'XXCMP_PARTY_REL_DFF';
    select context_user_selectable_flag into l_v from xxfnd_df_flexfields where descriptive_flexfield_code = 'XXCMP_PARTY_REL_DFF';
    ok('USER: the user picks the context', l_v = 'Y');
    rollback;
    -- segment: lookup validation, API name and sequence defaults
    select min(t.lookup_type) into l_lk from xxfnd_lookup_types t
     where not exists (select 1 from xxfnd_value_sets v where v.lookup_type = t.lookup_type) and length(t.lookup_type) <= 21;
    insert into xxfnd_df_segments (descriptive_flexfield_code, context_code, segment_code, column_name, prompt, value_set_code)
    select descriptive_flexfield_code, context_code, 'R92_TEST', 'ATTRIBUTE30', 'R92 test', 'LOOKUP:' || l_lk
      from xxfnd_df_contexts where descriptive_flexfield_code = 'XXCMP_PARTIES_DFF' and global_flag = 'Y' and rownum = 1;
    select value_set_code || '|' || api_name || '|' || sequence_number into l_v from xxfnd_df_segments where segment_code = 'R92_TEST';
    ok('lookup ' || l_lk || ' becomes its value set; API name and sequence defaulted: ' || l_v,
       l_v like 'XXFND_LK_' || l_lk || '|r92_test|%' and mod(to_number(substr(l_v, instr(l_v, '|', -1) + 1)), 10) = 0);
    select validation_type into l_v from xxfnd_value_sets where value_set_code = 'XXFND_LK_' || l_lk;
    ok('the lookup value set is INDEPENDENT', l_v = 'INDEPENDENT');
    rollback;
    xxfnd_util_pkg.set_install_mode(false);
    dbms_output.put_line(l_pass || ' pass, ' || l_fail || ' fail');
end;
/
exit
