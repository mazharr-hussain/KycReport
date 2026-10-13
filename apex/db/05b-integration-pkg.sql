--------------------------------------------------------------------------------
-- 05b XXFND_INTEGRATION_PKG (release 79). COMMON only (XXFUSION), before the row rules (08) that ask SYNC_RUNNING.
--   The Integrations component's package. Release 79 holds the Fusion HCM worker sync, moved from
--   XXFND_SECURITY_PKG (dropped in 16j); the one call procedure and the transmission log follow with the
--   Integrations release.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxfnd_integration_pkg authid definer as
    -- Upserts one Fusion worker (JSON object from the HCM publicWorkers resource).
    procedure upsert_fusion_worker(p_worker in json_object_t);
    -- Pages through Fusion HCM publicWorkers with the given web credential and refreshes the FUSION employees;
    -- workers no longer returned are disabled, not deleted.
    procedure sync_from_fusion(p_base_url              in varchar2,
                               p_credential_static_id  in varchar2,
                               p_page_size             in pls_integer default 200);
    -- True while SYNC_FROM_FUSION runs; lets the Fusion-owned-row trigger (XXFND_EMPLOYEES_SRC) tell the sync
    -- apart from a user edit.
    function sync_running return boolean;
    -- Sets each Fusion employee's user name and Fusion user id from their Fusion / identity-domain user account
    -- (HCM userAccounts: Username, UserId by PersonId); the user name is what single sign-on returns. Called by
    -- SYNC_FROM_FUSION; a worker without a user account keeps the work e-mail.
    procedure sync_user_names(p_base_url             in varchar2,
                              p_credential_static_id in varchar2,
                              p_page_size            in pls_integer default 200);
end xxfnd_integration_pkg;
/

create or replace package body xxfnd_integration_pkg as

    g_sync_running boolean := false;

    procedure upsert_fusion_worker(p_worker in json_object_t) is
        l_person_id   number        := p_worker.get_number('PersonId');
        l_number      varchar2(30)  := p_worker.get_string('PersonNumber');
        l_name        varchar2(240) := p_worker.get_string('DisplayName');
        l_email       varchar2(320) := lower(p_worker.get_string('WorkEmail'));
        l_dept        varchar2(240);
        l_job         varchar2(240);
        l_assignments json_array_t;
        l_asg         json_object_t;
    begin
        if l_person_id is null or l_email is null then
            return; -- a worker without a work email cannot sign in; skip
        end if;
        if p_worker.has('assignments') then
            l_assignments := p_worker.get_array('assignments');
            if l_assignments.get_size > 0 then
                l_asg  := treat(l_assignments.get(0) as json_object_t);
                l_dept := l_asg.get_string('DepartmentName');
                l_job  := l_asg.get_string('JobName');
            end if;
        end if;

        -- A LOCAL record created before the person existed in Fusion is adopted,
        -- not duplicated (the email and user name are unique).
        update xxfnd_employees
           set source_type = 'FUSION', fusion_person_id = l_person_id
         where source_type = 'LOCAL'
           and fusion_person_id is null
           and (email_address = l_email or user_name = upper(l_email));

        merge into xxfnd_employees e
        using (select l_person_id person_id from dual) s
           on (e.fusion_person_id = s.person_id)
         when matched then update set
              e.fusion_person_number = l_number,
              e.full_name            = nvl(l_name, e.full_name),
              e.email_address        = l_email,
              e.department_name      = l_dept,
              e.job_title            = l_job,
              e.enabled_flag         = 'Y',
              e.last_sync_date       = systimestamp
         when not matched then insert
              (source_type, fusion_person_id, fusion_person_number, user_name, full_name,
               email_address, department_name, job_title, last_sync_date)
              values
              ('FUSION', l_person_id, l_number, upper(l_email), nvl(l_name, l_email),
               l_email, l_dept, l_job, systimestamp);
    end upsert_fusion_worker;

    procedure sync_user_names(p_base_url             in varchar2,
                              p_credential_static_id in varchar2,
                              p_page_size            in pls_integer default 200) is
        l_offset   pls_integer := 0;
        l_response clob;
        l_doc      json_object_t;
        l_items    json_array_t;
        l_item     json_object_t;
        l_has_more boolean := true;
    begin
        while l_has_more loop
            l_response := apex_web_service.make_rest_request(
                              p_url                  => rtrim(p_base_url, '/')
                                                        || '/hcmRestApi/resources/11.13.18.05/userAccounts'
                                                        || '?onlyData=true&limit=' || p_page_size || '&offset=' || l_offset
                                                        || '&fields=Username,PersonId,UserId',
                              p_http_method          => 'GET',
                              p_credential_static_id => p_credential_static_id);
            if apex_web_service.g_status_code <> 200 then
                -- user names stay as they are; the worker sync itself is not failed
                apex_debug.warn('sync_user_names: HTTP %0 from userAccounts', apex_web_service.g_status_code);
                return;
            end if;
            l_doc   := json_object_t.parse(l_response);
            l_items := l_doc.get_array('items');
            for i in 0 .. l_items.get_size - 1 loop
                l_item := treat(l_items.get(i) as json_object_t);
                if l_item.get_number('PersonId') is not null and trim(l_item.get_string('Username')) is not null then
                    -- trigger XXFND_EMPLOYEES_RENAME moves the references (rename_user)
                    update xxfnd_employees
                       set user_name      = upper(trim(l_item.get_string('Username'))),
                           fusion_user_id = nvl(to_char(l_item.get_number('UserId')), fusion_user_id)
                     where fusion_person_id = l_item.get_number('PersonId')
                       and (user_name <> upper(trim(l_item.get_string('Username')))
                            or nvl(fusion_user_id, '#') <> nvl(to_char(l_item.get_number('UserId')), nvl(fusion_user_id, '#')));
                end if;
            end loop;
            l_has_more := nvl(l_doc.get_boolean('hasMore'), false);
            l_offset   := l_offset + p_page_size;
            commit;
        end loop;
    end sync_user_names;

    procedure sync_from_fusion(p_base_url              in varchar2,
                               p_credential_static_id  in varchar2,
                               p_page_size             in pls_integer default 200) is
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
                  || '?onlyData=true&limit=' || p_page_size || '&offset=' || l_offset
                  || '&fields=PersonId,PersonNumber,DisplayName,WorkEmail;assignments:DepartmentName,JobName';
            l_response := apex_web_service.make_rest_request(
                              p_url                  => l_url,
                              p_http_method          => 'GET',
                              p_credential_static_id => p_credential_static_id);
            if apex_web_service.g_status_code <> 200 then
                raise_application_error(-20110, 'Fusion HCM sync failed with HTTP '
                    || apex_web_service.g_status_code || ': ' || dbms_lob.substr(l_response, 500, 1));
            end if;
            l_doc   := json_object_t.parse(l_response);
            l_items := l_doc.get_array('items');
            for i in 0 .. l_items.get_size - 1 loop
                upsert_fusion_worker(treat(l_items.get(i) as json_object_t));
            end loop;
            l_has_more := nvl(l_doc.get_boolean('hasMore'), false);
            l_offset   := l_offset + p_page_size;
            commit;
        end loop;

        -- user names = the Fusion / identity-domain user names (the e-mail stays for workers without an account)
        sync_user_names(p_base_url, p_credential_static_id, p_page_size);

        -- Workers no longer returned by Fusion (terminated) are disabled, not deleted.
        update xxfnd_employees e
           set e.enabled_flag = 'N'
         where e.source_type = 'FUSION'
           and e.enabled_flag = 'Y'
           and (e.last_sync_date is null or e.last_sync_date < l_run_ts);
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

end xxfnd_integration_pkg;
/
