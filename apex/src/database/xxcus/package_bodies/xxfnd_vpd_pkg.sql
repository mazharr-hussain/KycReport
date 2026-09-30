create or replace package body xxcus.xxfnd_vpd_pkg as

    g_trusted pls_integer := 0;
    c_policy  constant varchar2(30) := 'XXFND_DATA_SECURITY';

    procedure begin_trusted is
    begin
        g_trusted := g_trusted + 1;
    end begin_trusted;

    procedure end_trusted is
    begin
        g_trusted := greatest(g_trusted - 1, 0);
    end end_trusted;

    function quoted_list (
        p_values in varchar2
    ) return varchar2 is
        l_out varchar2(32767);
    begin
        for v in (
            select
                trim(column_value) val
            from
                table ( apex_string.split(p_values, ',') )
            where
                trim(column_value) is not null
        ) loop
            l_out := l_out
                     ||
                case
                    when l_out is not null then
                        ','
                end
                     || dbms_assert.enquote_literal(replace(v.val, '''', ''''''));
        end loop;

        return l_out;
    end quoted_list;

    -- Users who delegate to p_user today (Workflow Setup > Delegations), comma-separated.
    function delegators (
        p_user in varchar2
    ) return varchar2 is
        l_list varchar2(4000);
    begin
        select
            listagg(distinct upper(delegator_user_name),
                             ',') within group(
            order by
                1
            )
        into l_list
        from
            xxfnd_wf_delegations
        where
                upper(delegate_user_name) = p_user
            and trunc(sysdate) between start_date and end_date;

        return l_list;
    end delegators;

    function policy (
        p_schema in varchar2,
        p_object in varchar2
    ) return varchar2 is

        l_user      varchar2(255) := upper(sys_context('APEX$SESSION', 'APP_USER'));
        l_predicate varchar2(32767);
        l_part      varchar2(4000);
    begin
        -- Install scripts, scheduler jobs and developer sessions run without an APEX user. APEX runs
        -- workflow activities and automations in scheduler background jobs (as NOBODY): system work too.
        -- Browser requests through ORDS never run in a scheduler job.
        if l_user is null
           or g_trusted > 0
        or sys_context('USERENV', 'BG_JOB_ID') is not null then
            return null;
        end if;

        for r in (
            select distinct
                d.rule_type,
                d.column_name,
                d.value_list
            from
                     xxfnd_data_security_rules d
                join xxfnd_user_roles_v ur on ur.role_code = d.role_code
            where
                    ur.user_name = l_user
                and ur.active_flag = 'Y'
                and d.enabled_flag = 'Y'
                and d.table_name = upper(p_object)
        ) loop
            if r.rule_type = 'ALL_ROWS' then
                return null;
            end if;
            l_part :=
                case r.rule_type
                    when 'OWN_RECORDS'    then
                            -- the user's own rows, and those of anyone currently delegating to the user
                        'upper('
                        || dbms_assert.simple_sql_name(r.column_name)
                        || ') in ('
                        || quoted_list(l_user || nvl2(
                            delegators(l_user),
                            ',' || delegators(l_user),
                            null
                        ))
                        || ')'
                    when 'COLUMN_IN_LIST' then
                        dbms_assert.simple_sql_name(r.column_name)
                        || ' in ('
                        || quoted_list(r.value_list)
                        || ')'
                end;

            if l_part is not null then
                l_predicate := l_predicate
                               ||
                    case
                        when l_predicate is not null then
                            ' or '
                    end
                               || '('
                               || l_part
                               || ')';
            end if;

        end loop;
        -- No rule for this user and table: deny.
        return nvl(l_predicate, '1 = 0');
    end policy;

    procedure apply_policies is
        l_count pls_integer;
    begin
        for t in (
            select distinct
                d.table_name
            from
                     xxfnd_data_security_rules d
                join user_tables u on u.table_name = d.table_name
        ) loop
            select
                count(*)
            into l_count
            from
                user_policies
            where
                    object_name = t.table_name
                and policy_name = c_policy;

            if l_count = 0 then
                dbms_rls.add_policy(
                    object_schema   => sys_context('USERENV', 'CURRENT_SCHEMA'),
                    object_name     => t.table_name,
                    policy_name     => c_policy,
                    function_schema => sys_context('USERENV', 'CURRENT_SCHEMA'),
                    policy_function => 'XXFND_VPD_PKG.POLICY',
                    statement_types => 'SELECT,INSERT,UPDATE,DELETE',
                    update_check    => true,
                    policy_type     => dbms_rls.dynamic
                );

            end if;

        end loop;
    end apply_policies;

end xxfnd_vpd_pkg;
/


-- sqlcl_snapshot {"hash":"f4fb3b14dfc30fc925d00b62fd7c73e126198ff1","type":"PACKAGE_BODY","name":"XXFND_VPD_PKG","schemaName":"XXCUS","sxml":""}