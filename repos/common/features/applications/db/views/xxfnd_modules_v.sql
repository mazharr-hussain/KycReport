
-- The modules the current user may open (one of its features is on the admin menu for them), with a short state
-- that shows a problem without opening the screens. Used by the navigation menu, Home and page 100.
create or replace view xxfnd_modules_v as
select m.lookup_code                       as module_code,
       m.meaning                           as module_name,
       m.description,
       nvl(m.tag, 'fa-folder')             as icon_css,
       m.display_sequence,
       case m.lookup_code
           when 'PLATFORM' then
               (select count(*) || ' disabled application(s)'
                  from xxfnd_applications where enabled_flag = 'N' having count(*) > 0)
           when 'SECURITY' then
               (select count(*) || ' user(s) without a role'
                  from xxhr_employees e
                 where e.enabled_flag = 'Y'
                   and not exists (select 1 from xxfnd_user_roles r
                                    where r.employee_id = e.employee_id and r.enabled_flag = 'Y'
                                      and trunc(sysdate) between r.start_date_active and nvl(r.end_date_active, trunc(sysdate)))
                having count(*) > 0)
           when 'DOCUMENTS_RECORDS' then
               'Retention not active yet'
           when 'WORKFLOW' then
               ltrim((select case when max(decode(application_code, 'COMMON', email_enabled_flag)) = 'N'
                                  then 'E-mail off for the workspace.' end
                        from xxfnd_applications)
                     || (select ' ' || count(*) || ' workflow(s) switched off'
                           from xxfnd_workflow_processes where workflow_enabled_flag = 'N' having count(*) > 0))
           when 'INTEGRATIONS' then
               -- release 86: the workspace servers (XXFND_SERVERS_V, 05b); XXFND_INTEGRATION_ENDPOINTS retired
               (select count(*) || ' server(s) incomplete or failing'
                  from xxfnd_servers_v where status in ('INCOMPLETE', 'FAILED') having count(*) > 0)
       end                                 as module_state
  from xxfnd_lookup_values m
 where m.lookup_type  = 'XXFND_MODULE'
   and m.enabled_flag = 'Y'
   and exists (select 1 from xxfnd_admin_menu_v a
                join xxfnd_feature_pages fp on fp.feature_code = a.feature_code and fp.app_alias = 'COMMON'
               where a.feature_group = m.lookup_code);

comment on table xxfnd_modules_v is 'COMMON modules (lookup XXFND_MODULE) the current user may open, with their state.';
