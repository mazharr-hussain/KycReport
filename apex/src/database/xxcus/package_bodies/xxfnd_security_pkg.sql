create or replace package body xxcus.xxfnd_security_pkg as

    g_sync_running boolean := false;

    function norm_user (
        p_user_name in varchar2
    ) return varchar2 is
    begin
        return upper(nvl(p_user_name, xxfnd_util_pkg.current_user));
    end norm_user;

    function current_employee_id return number is
        l_id   xxfnd_employees.employee_id%type;
        l_user varchar2(255) := norm_user(null);   -- private functions cannot be called from SQL
    begin
        select
            e.employee_id
        into l_id
        from
            xxfnd_employees e
        where
                e.user_name = l_user
            and e.enabled_flag = 'Y'
            and trunc(sysdate) between e.start_date_active and nvl(e.end_date_active,
                                                                   trunc(sysdate));

        return l_id;
    exception
        when no_data_found then
            return null;
    end current_employee_id;

    function has_role (
        p_role_code in varchar2,
        p_user_name in varchar2 default null
    ) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select
            count(*)
        into l_count
        from
            xxfnd_user_roles_v v
        where
                v.user_name = l_user
            and v.role_code = p_role_code
            and v.active_flag = 'Y';

        return l_count > 0;
    end has_role;

    function has_role_yn (
        p_role_code in varchar2,
        p_user_name in varchar2 default null
    ) return varchar2 is
    begin
        return
            case
                when has_role(p_role_code, p_user_name) then
                    'Y'
                else
                    'N'
            end;
    end has_role_yn;

    function has_any_role (
        p_role_codes in varchar2,
        p_user_name  in varchar2 default null
    ) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select
            count(*)
        into l_count
        from
            xxfnd_user_roles_v v
        where
                v.user_name = l_user
            and v.active_flag = 'Y'
            and v.role_code in (
                select
                    trim(column_value)
                from
                    table ( apex_string.split(p_role_codes, ',') )
            );

        return l_count > 0;
    end has_any_role;

    function has_any_role_yn (
        p_role_codes in varchar2,
        p_user_name  in varchar2 default null
    ) return varchar2 is
    begin
        return
            case
                when has_any_role(p_role_codes, p_user_name) then
                    'Y'
                else
                    'N'
            end;
    end has_any_role_yn;

    function can_view_sensitive (
        p_user_name in varchar2 default null
    ) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select
            count(*)
        into l_count
        from
                 xxfnd_user_roles_v v
            join xxfnd_roles r on r.role_code = v.role_code
        where
                v.user_name = l_user
            and v.active_flag = 'Y'
            and r.view_sensitive_flag = 'Y';

        return l_count > 0;
    end can_view_sensitive;

    function sod_conflict (
        p_role_code   in varchar2,
        p_prior_roles in apex_t_varchar2 default null,
        p_user_name   in varchar2 default null
    ) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        -- Same record: the user already acted on this record under a conflicting role.
        if
            p_prior_roles is not null
            and p_prior_roles.count > 0
        then
            select
                count(*)
            into l_count
            from
                xxfnd_sod_rules s
            where
                    s.enabled_flag = 'Y'
                and s.conflict_scope = 'SAME_RECORD'
                and ( ( s.role_code_1 = p_role_code
                        and s.role_code_2 in (
                    select
                        column_value
                    from
                        table ( p_prior_roles )
                ) )
                      or ( s.role_code_2 = p_role_code
                           and s.role_code_1 in (
                    select
                        column_value
                    from
                        table ( p_prior_roles )
                ) ) );

            if l_count > 0 then
                return true;
            end if;
        end if;

        -- Global: the user holds a role that may never be combined with p_role_code.
        select
            count(*)
        into l_count
        from
                 xxfnd_sod_rules s
            join xxfnd_user_roles_v v on v.user_name = l_user
                                         and v.active_flag = 'Y'
                                         and v.role_code = case
                                                               when s.role_code_1 = p_role_code then
                                                                   s.role_code_2
                                                               else
                                                                   s.role_code_1
                                                           end
        where
                s.enabled_flag = 'Y'
            and s.conflict_scope = 'GLOBAL'
            and p_role_code in ( s.role_code_1, s.role_code_2 );

        return l_count > 0;
    end sod_conflict;

    procedure upsert_fusion_worker (
        p_worker in json_object_t
    ) is

        l_person_id   number := p_worker.get_number('PersonId');
        l_number      varchar2(30) := p_worker.get_string('PersonNumber');
        l_name        varchar2(240) := p_worker.get_string('DisplayName');
        l_email       varchar2(320) := lower(p_worker.get_string('WorkEmail'));
        l_dept        varchar2(240);
        l_job         varchar2(240);
        l_assignments json_array_t;
        l_asg         json_object_t;
    begin
        if l_person_id is null
           or l_email is null then
            return; -- a worker without a work email cannot sign in; skip
        end if;
        if p_worker.has('assignments') then
            l_assignments := p_worker.get_array('assignments');
            if l_assignments.get_size > 0 then
                l_asg := treat(l_assignments.get(0) as json_object_t);
                l_dept := l_asg.get_string('DepartmentName');
                l_job := l_asg.get_string('JobName');
            end if;

        end if;

        -- A LOCAL record created before the person existed in Fusion is adopted,
        -- not duplicated (the email and user name are unique).
        update xxfnd_employees
        set
            source_type = 'FUSION',
            fusion_person_id = l_person_id
        where
                source_type = 'LOCAL'
            and fusion_person_id is null
            and ( email_address = l_email
                  or user_name = upper(l_email) );

        merge into xxfnd_employees e
        using (
            select
                l_person_id person_id
            from
                dual
        ) s on ( e.fusion_person_id = s.person_id )
        when matched then update
        set e.fusion_person_number = l_number,
            e.full_name = nvl(l_name, e.full_name),
            e.email_address = l_email,
            e.user_name = upper(l_email),
            e.department_name = l_dept,
            e.job_title = l_job,
            e.enabled_flag = 'Y',
            e.last_sync_date = systimestamp
        when not matched then
        insert (
            source_type,
            fusion_person_id,
            fusion_person_number,
            user_name,
            full_name,
            email_address,
            department_name,
            job_title,
            last_sync_date )
        values
            ( 'FUSION',
              l_person_id,
              l_number,
              upper(l_email),
              nvl(l_name, l_email),
              l_email,
              l_dept,
              l_job,
              systimestamp );

    end upsert_fusion_worker;

    procedure sync_from_fusion (
        p_base_url             in varchar2,
        p_credential_static_id in varchar2,
        p_page_size            in pls_integer default 200
    ) is

        l_offset   pls_integer := 0;
        l_response clob;
        l_doc      json_object_t;
        l_items    json_array_t;
        l_has_more boolean := true;
        l_url      varchar2(4000);
        l_run_ts   timestamp := systimestamp;
    begin
        g_sync_running := true;
        while l_has_more loop
            l_url := rtrim(p_base_url, '/')
                     || '/hcmRestApi/resources/11.13.18.05/publicWorkers'
                     || '?onlyData=true&limit='
                     || p_page_size
                     || '&offset='
                     || l_offset
                     || '&fields=PersonId,PersonNumber,DisplayName,WorkEmail;assignments:DepartmentName,JobName';

            l_response := apex_web_service.make_rest_request(
                p_url                  => l_url,
                p_http_method          => 'GET',
                p_credential_static_id => p_credential_static_id
            );

            if apex_web_service.g_status_code <> 200 then
                raise_application_error(-20110,
                                        'Fusion HCM sync failed with HTTP '
                                        || apex_web_service.g_status_code
                                        || ': '
                                        || dbms_lob.substr(l_response, 500, 1));
            end if;

            l_doc := json_object_t.parse(l_response);
            l_items := l_doc.get_array('items');
            for i in 0..l_items.get_size - 1 loop
                upsert_fusion_worker(treat(l_items.get(i) as json_object_t));
            end loop;

            l_has_more := nvl(
                l_doc.get_boolean('hasMore'),
                false
            );
            l_offset := l_offset + p_page_size;
            commit;
        end loop;

        -- Workers no longer returned by Fusion (terminated) are disabled, not deleted.
        update xxfnd_employees e
        set
            e.enabled_flag = 'N'
        where
                e.source_type = 'FUSION'
            and e.enabled_flag = 'Y'
            and ( e.last_sync_date is null
                  or e.last_sync_date < l_run_ts );

        commit;
        g_sync_running := false;
    exception
        when others then
            g_sync_running := false;
            raise;
    end sync_from_fusion;

    function sync_running return boolean is
    begin
        return g_sync_running;
    end sync_running;

    procedure bootstrap_admin (
        p_user_name in varchar2,
        p_full_name in varchar2 default null,
        p_email     in varchar2 default null
    ) is

        l_user  varchar2(255) := upper(trim(p_user_name));
        l_email varchar2(320) := lower(trim(coalesce(p_email,
                                                     case
                                                         when instr(p_user_name, '@') > 0 then
                                                                p_user_name
                                                     end,
                                                     p_user_name || '@unknown.invalid')));
        l_id    number;
    begin
        if l_user is null then
            return;
        end if;
        begin
            select
                employee_id
            into l_id
            from
                xxfnd_employees
            where
                user_name = l_user;

            update xxfnd_employees
            set
                enabled_flag = 'Y',
                end_date_active = null
            where
                employee_id = l_id;

        exception
            when no_data_found then
                insert into xxfnd_employees (
                    source_type,
                    user_name,
                    full_name,
                    email_address
                ) values
                    ( 'LOCAL',
                      l_user,
                      coalesce(
                          trim(p_full_name),
                          l_user
                      ),
                      l_email )
                returning employee_id into l_id;

        end;

        merge into xxfnd_user_roles t
        using (
            select
                l_id           employee_id,
                'SYSTEM_ADMIN' role_code
            from
                dual
        ) s on ( t.employee_id = s.employee_id
                 and t.role_code = s.role_code
                 and t.end_date_active is null )
        when matched then update
        set t.enabled_flag = 'Y'
        when not matched then
        insert (
            employee_id,
            role_code )
        values
            ( s.employee_id,
              s.role_code );

    end bootstrap_admin;

end xxfnd_security_pkg;
/


-- sqlcl_snapshot {"hash":"2f1216e5a521d9df2e8b7155d2e50af571e69f54","type":"PACKAGE_BODY","name":"XXFND_SECURITY_PKG","schemaName":"XXCUS","sxml":""}