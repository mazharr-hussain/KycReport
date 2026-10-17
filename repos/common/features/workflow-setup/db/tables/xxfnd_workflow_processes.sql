--------------------------------------------------------------------------------
-- 24 Workflow module (release 82, C5). COMMON only (XXFUSION), after 21b (the processes are synced there).
--   - XXFND_WORKFLOW_PROCESSES.PARTICIPANTS_TYPE (added in 09e, before XXFND_WORKFLOW_PKG): RULE or CHOSEN.
--   - RFI is a process of every registered application (XXFND_WORKFLOW_PKG.SYNC_PROCESSES adds it): its workflow
--     switch (off = no review task) and e-mail switch are set in the Process Catalogue like any other process.
--   - The Approval Setup type "Case request for information" (CASE_RFI) is disabled: the recipient of a request for
--     information is chosen by the person who raises it, the requester by default (no approval rule). Its rows stay.
-- Idempotent: checked steps; a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_util_pkg.set_install_mode(true);
    begin
        xxfnd_workflow_pkg.sync_processes;   -- adds the RFI process of every application
    exception
        when others then
            -- the package was recompiled earlier in this install session (its state is discarded once): call again
            if sqlcode in (-4068, -4061, -4065, -6508) then
                xxfnd_workflow_pkg.sync_processes;
            else
                raise;
            end if;
    end;
    update xxfnd_workflow_processes set participants_type = 'CHOSEN'
     where process_code = xxfnd_workflow_pkg.c_rfi_process and participants_type <> 'CHOSEN';
    update xxfnd_approval_types set enabled_flag = 'N'
     where approval_type_code = 'CASE_RFI' and enabled_flag = 'Y';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/

--------------------------------------------------------------------------------
-- The COMMON workflow processes RFI and CONFIG_CHANGE in the Process Catalogue (from the APEX dictionary), and the
-- push keys of COMMON in a new workspace: an imported application carries only the public key of its push
-- credential, so the key pair is made here while no device is subscribed yet.
--------------------------------------------------------------------------------
declare
    l_subs number;
    l_app  number;
begin
    xxfnd_util_pkg.set_install_mode(true);
    begin
        xxfnd_workflow_pkg.sync_processes;
    exception
        when others then
            -- the package was recompiled earlier in this install session (its state is discarded once): call again
            if sqlcode in (-4068, -4061, -4065, -6508) then
                xxfnd_workflow_pkg.sync_processes;
            else
                raise;
            end if;
    end;
    update xxfnd_workflow_processes set participants_type = 'RULE'
     where process_code = 'CONFIG_CHANGE' and participants_type <> 'RULE';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
    select max(apex_application_id) into l_app from xxfnd_applications where application_code = 'COMMON';
    select count(*) into l_subs from apex_appl_push_subscriptions where application_id = l_app;
    if l_app is not null and l_subs = 0 then
        begin
            apex_pwa.generate_push_credentials(p_application_id => l_app);
            commit;
        exception
            when others then
                null;   -- not a progressive web app here (e.g. the application is not imported yet): set up in App Builder
        end;
    end if;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
