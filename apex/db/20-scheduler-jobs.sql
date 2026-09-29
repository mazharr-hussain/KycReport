--------------------------------------------------------------------------------
-- 11_jobs.sql
-- Scheduler jobs, created enabled. Each run does nothing until its
-- Application Settings are filled in (MAIL_FROM; FUSION_BASE_URL and
-- FUSION_CREDENTIAL_STATIC_ID), so no manual step is needed after install.
--   XXFND_WF_MAILER  every 5 minutes: workflow timeouts + queued notifications
--                    (NFR: notification within 5 minutes of the transition)
--   XXFND_HCM_SYNC   daily 02:00: refresh FUSION employees from Fusion HCM
-- Both open an APEX session for application alias KYC in workspace XXCUS so
-- that APEX_MAIL, Web Credentials and Application Settings are available.
--------------------------------------------------------------------------------
begin
    for j in (select job_name from user_scheduler_jobs where job_name in ('XXFND_WF_MAILER','XXFND_HCM_SYNC')) loop
        dbms_scheduler.drop_job(j.job_name, force => true);
    end loop;

    dbms_scheduler.create_job(
        job_name        => 'XXFND_WF_MAILER',
        job_type        => 'PLSQL_BLOCK',
        job_action      => q'[begin xxfnd_wf_pkg.send_queued(p_workspace => 'XXCUS', p_app_alias => 'KYC'); end;]',
        start_date      => systimestamp,
        repeat_interval => 'FREQ=MINUTELY;INTERVAL=5',
        enabled         => true,
        comments        => 'Workflow timeouts and notification mailer (XXFND_WF_PKG.SEND_QUEUED).');

    dbms_scheduler.create_job(
        job_name        => 'XXFND_HCM_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => q'[
declare
    l_app_id number;
begin
    select application_id into l_app_id
      from apex_applications
     where workspace = 'XXCUS' and upper(alias) = 'KYC'
       and application_id = (select max(application_id) from apex_applications
                              where workspace = 'XXCUS' and upper(alias) = 'KYC');
    apex_session.create_session(p_app_id => l_app_id, p_page_id => 1, p_username => 'XXFND_HCM_SYNC');
    if apex_app_setting.get_value('FUSION_BASE_URL') is not null
       and apex_app_setting.get_value('FUSION_CREDENTIAL_STATIC_ID') is not null then
        xxfnd_security_pkg.sync_from_fusion(
            p_base_url             => apex_app_setting.get_value('FUSION_BASE_URL'),
            p_credential_static_id => apex_app_setting.get_value('FUSION_CREDENTIAL_STATIC_ID'));
    end if;
    apex_session.delete_session;
end;]',
        start_date      => trunc(systimestamp) + interval '1' day + interval '2' hour,
        repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0',
        enabled         => true,
        comments        => 'Fusion HCM publicWorkers -> XXFND_EMPLOYEES (XXFND_SECURITY_PKG.SYNC_FROM_FUSION).');
end;
/
