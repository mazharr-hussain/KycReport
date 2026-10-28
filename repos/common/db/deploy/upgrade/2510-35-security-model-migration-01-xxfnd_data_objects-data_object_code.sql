--------------------------------------------------------------------------------
-- 35 Security model - moving today's access into it (release 96). Runs once (release C96_SECURITY_MODEL):
--   1. dimension DEPARTMENT (organizations of type DEPARTMENT) and the departments used by the rules
--   2. every table with a data access rule becomes a data object (dimension column, owner column)
--   3. rules assigned to a role -> that role's data access (ALL / VALUES / OWN); a role's fixed values -> the values of
--      each of its assignments
--   4. rules assigned to a user -> no direct access in the model: values on the user's assignments of the
--      application's roles that reach the object; ALL / OWN -> a data role "<object> - All records / Own records"
--   5. the release 76 department roles REQUESTING_FINANCE / REQUESTING_PROCUREMENT and every assignment of them go
--   6. each user's applications from the roles they hold
-- The old rule tables stay as they were (read only) until the access is confirmed; the row policy reads the model
-- for every data object. Rows written here are COMMON's own (install script).
--------------------------------------------------------------------------------
declare
    c_release constant varchar2(30) := 'C96_SECURITY_MODEL';

    function obj_code(p_table in varchar2) return varchar2 is
        l_code xxfnd_data_objects.data_object_code%type;
    begin
        select max(data_object_code) into l_code from xxfnd_data_objects where table_name = p_table;
        return l_code;
    end obj_code;

    function dim_for(p_column in varchar2) return varchar2 is
        l_dim varchar2(30) := case when upper(p_column) like '%DEPARTMENT%' then 'DEPARTMENT'
                                   else substr(upper(p_column), 1, 30) end;
    begin
        if l_dim <> 'DEPARTMENT' then
            merge into xxfnd_data_dimensions t using (select l_dim c from dual) x on (t.dimension_code = x.c)
             when not matched then insert (dimension_code, dimension_name, application_code, value_source, description)
                  values (x.c, initcap(replace(x.c, '_', ' ')), 'COMMON', 'FREE', 'Release 96: from a data access rule on ' || x.c || '.');
        end if;
        return l_dim;
    end dim_for;

    procedure add_value(p_user_role_id in number, p_dim in varchar2, p_values in varchar2) is
    begin
        insert into xxfnd_assignment_values (user_role_id, dimension_code, value_code)
        select distinct p_user_role_id, p_dim, upper(trim(column_value))
          from table(apex_string.split(p_values, ','))
         where trim(column_value) is not null
           and not exists (select 1 from xxfnd_assignment_values v
                            where v.user_role_id = p_user_role_id and v.dimension_code = p_dim
                              and v.data_object_code is null and v.value_code = upper(trim(column_value)));
    end add_value;

    procedure grant_level(p_role in varchar2, p_obj in varchar2, p_level in varchar2) is
    begin
        merge into xxfnd_role_data_access t
        using (select p_role r, p_obj o, p_level l from dual) x
           on (t.role_code = x.r and t.data_object_code = x.o and t.access_level = x.l)
         when not matched then insert (role_code, data_object_code, access_level) values (x.r, x.o, x.l);
    end grant_level;
begin
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_vpd_pkg.begin_trusted;

    -- 1. the Department dimension (always present)
    merge into xxfnd_data_dimensions t using (select 'DEPARTMENT' c from dual) x on (t.dimension_code = x.c)
     when not matched then insert (dimension_code, dimension_name, application_code, value_source, organization_type, description)
          values ('DEPARTMENT', 'Department', 'COMMON', 'ORGANIZATION', 'DEPARTMENT',
                  'Release 96: the department of a record (e.g. the requesting department of a KYC request).');

    if not xxfnd_ddl_pkg.release_applied(c_release) then
        -- the departments the rules use
        for v in (select distinct upper(trim(s.column_value)) code
                    from xxfnd_data_security_rules d, table(apex_string.split(d.value_list, ',')) s
                   where d.rule_type = 'COLUMN_IN_LIST' and upper(d.column_name) like '%DEPARTMENT%'
                     and trim(s.column_value) is not null) loop
            merge into xxhr_organizations t
            using (select 'DEPARTMENT' ty, v.code c from dual) x on (t.organization_type = x.ty and t.organization_code = x.c)
             when not matched then insert (organization_type, organization_code, organization_name, application_code)
                  values (x.ty, x.c,
                          nvl((select max(l.meaning) from xxfnd_lookup_values l
                                where l.lookup_code = x.c and l.lookup_type like '%DEPARTMENT%'), initcap(x.c)), 'COMMON');
        end loop;

        -- 2. data objects
        for t in (select d.table_name,
                         max(case when d.rule_type = 'COLUMN_IN_LIST' then upper(d.column_name) end) dim_col,
                         max(case when d.rule_type = 'OWN_RECORDS' then upper(d.column_name) end) own_col,
                         max(r.application_code) app
                    from xxfnd_data_security_rules d
                    left join xxfnd_roles r on r.role_code = d.role_code
                   where exists (select 1 from user_tables u where u.table_name = d.table_name)
                      or d.table_name like 'XXCMP\_%' escape '\'
                   group by d.table_name) loop
            if obj_code(t.table_name) is null then
                insert into xxfnd_data_objects (data_object_code, object_name, application_code, table_name)
                values (substr(t.table_name, 1, 60), initcap(replace(regexp_replace(t.table_name, '^XX[A-Z]+_'), '_', ' ')),
                        case when t.table_name like 'XXFND\_%' escape '\' or t.table_name like 'XXHR\_%' escape '\' then 'COMMON'
                             else nvl(t.app, 'COMMON') end,
                        t.table_name);
            end if;
            declare
                l_dim varchar2(30) := case when t.dim_col is not null then dim_for(t.dim_col) end;
            begin
                update xxfnd_data_objects o
                   set o.dimension_column = nvl(o.dimension_column, t.dim_col),
                       o.dimension_code   = nvl(o.dimension_code, l_dim),
                       o.owner_column     = nvl(o.owner_column, t.own_col)
                 where o.table_name = t.table_name;
            end;
        end loop;

        -- 3. rules assigned to roles (the department roles go below)
        for a in (select distinct a.role_code, d.table_name, d.rule_type, d.column_name, d.value_list
                    from xxfnd_data_rule_assignments a
                    join xxfnd_data_security_rules d on d.rule_id = a.rule_id and d.enabled_flag = 'Y'
                   where a.role_code is not null
                     and a.role_code not in ('REQUESTING_FINANCE', 'REQUESTING_PROCUREMENT')) loop
            grant_level(a.role_code, obj_code(a.table_name),
                        case a.rule_type when 'ALL_ROWS' then 'ALL' when 'OWN_RECORDS' then 'OWN' else 'VALUES' end);
            if a.rule_type = 'COLUMN_IN_LIST' then
                for ur in (select user_role_id from xxfnd_user_roles where role_code = a.role_code) loop
                    add_value(ur.user_role_id, dim_for(a.column_name), a.value_list);
                end loop;
            end if;
        end loop;

        -- 4. rules assigned to users
        for a in (select a.user_id, d.table_name, d.rule_type, d.column_name, d.value_list, o.data_object_code,
                         o.application_code
                    from xxfnd_data_rule_assignments a
                    join xxfnd_data_security_rules d on d.rule_id = a.rule_id and d.enabled_flag = 'Y'
                    join xxfnd_data_objects o on o.table_name = d.table_name
                   where a.user_id is not null) loop
            if a.rule_type = 'COLUMN_IN_LIST' then
                -- the user's roles that reach the object (else the user's roles of its application) get VALUES access
                -- and the values on the user's assignment
                for ur in (select ur.user_role_id, ur.role_code
                             from xxfnd_user_roles ur join xxfnd_roles r on r.role_code = ur.role_code
                            where ur.user_id = a.user_id and ur.enabled_flag = 'Y'
                              and ur.role_code not in ('REQUESTING_FINANCE', 'REQUESTING_PROCUREMENT')
                              and (exists (select 1 from xxfnd_role_data_access x
                                            where x.role_code = ur.role_code and x.data_object_code = a.data_object_code)
                                   or (r.application_code = a.application_code
                                       and not exists (select 1 from xxfnd_user_roles u2 join xxfnd_role_data_access x2
                                                         on x2.role_code = u2.role_code
                                                        where u2.user_id = a.user_id and u2.enabled_flag = 'Y'
                                                          and x2.data_object_code = a.data_object_code)))) loop
                    grant_level(ur.role_code, a.data_object_code, 'VALUES');
                    add_value(ur.user_role_id, dim_for(a.column_name), a.value_list);
                end loop;
            else
                -- a data role holding only that access, assigned to the user
                declare
                    l_role varchar2(30) := substr(a.data_object_code, 1, 22) || case a.rule_type when 'ALL_ROWS' then '_ALL' else '_OWN' end || '_DATA';
                begin
                    merge into xxfnd_roles t using (select l_role c from dual) x on (t.role_code = x.c)
                     when not matched then insert (role_code, application_code, role_name, description)
                          values (x.c, a.application_code,
                                  (select object_name from xxfnd_data_objects where data_object_code = a.data_object_code)
                                  || case a.rule_type when 'ALL_ROWS' then ' - All records' else ' - Own records' end,
                                  'Release 96: a data role made from a data access rule given to a user directly.');
                    grant_level(l_role, a.data_object_code, case a.rule_type when 'ALL_ROWS' then 'ALL' else 'OWN' end);
                    insert into xxfnd_user_roles (user_id, employee_id, role_code)
                    select u.user_id, u.employee_id, l_role from xxfnd_users u
                     where u.user_id = a.user_id
                       and not exists (select 1 from xxfnd_user_roles x where x.user_id = u.user_id and x.role_code = l_role);
                end;
            end if;
        end loop;

        -- 5. the release 76 department roles: their assignments, privileges, rules and the roles themselves
        for r in (select role_code from xxfnd_roles where role_code in ('REQUESTING_FINANCE', 'REQUESTING_PROCUREMENT')) loop
            delete from xxfnd_user_roles where role_code = r.role_code;
            delete from xxfnd_role_privileges where role_code = r.role_code;
            delete from xxfnd_role_members where r.role_code in (role_code, member_role_code);
            delete from xxfnd_sod_rules where r.role_code in (role_code_1, role_code_2);
            delete from xxfnd_data_rule_assignments where role_code = r.role_code
                or rule_id in (select rule_id from xxfnd_data_security_rules where role_code = r.role_code);
            delete from xxfnd_data_security_rules where role_code = r.role_code;
            delete from xxfnd_roles where role_code = r.role_code;
        end loop;

        xxfnd_ddl_pkg.mark_release(c_release, 'Release 96: data access rules moved into the security model');
    end if;

    -- 6. each user's applications from the roles they hold (every run: only what is missing)
    insert into xxfnd_user_applications (user_id, application_code)
    select distinct ur.user_id, r.application_code
      from xxfnd_user_roles ur join xxfnd_roles r on r.role_code = ur.role_code
     where ur.user_id is not null and ur.enabled_flag = 'Y'
       and exists (select 1 from xxfnd_applications a where a.application_code = r.application_code)
       and not exists (select 1 from xxfnd_user_applications x where x.user_id = ur.user_id and x.application_code = r.application_code);

    xxfnd_vpd_pkg.clear_cache;
    xxfnd_vpd_pkg.end_trusted;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_vpd_pkg.end_trusted;
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
