--------------------------------------------------------------------------------
-- 19b Enable the application's automations  (release R14)
-- An application import leaves every automation disabled, whatever the export says; without this the task
-- reminders and escalations, the Fusion HCM sync and the KYC monitoring would never run.
-- Runs last, on install and on every upgrade.
--------------------------------------------------------------------------------
declare
    l_app number := to_number(v('APP_ID'));
begin
    if l_app is null then
        select max(application_id) into l_app from apex_applications where upper(alias) = 'KYC';
    end if;
    for a in (select static_id from apex_appl_automations
               where application_id = l_app and polling_status_code <> 'ACTIVE') loop
        apex_automation.enable(p_application_id => l_app, p_static_id => a.static_id);
    end loop;
    commit;
end;
/
