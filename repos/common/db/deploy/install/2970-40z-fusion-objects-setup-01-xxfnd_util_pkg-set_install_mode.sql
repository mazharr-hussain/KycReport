--------------------------------------------------------------------------------
-- 40z Fusion Objects setup (release 107). COMMON only (XXFUSION), after the Fusion Objects tables and packages.
--   - The messages of the Fusion Objects engine (ORA-20360 to -20374).
--   - Integration purpose FUSION_OBJECTS: every engine call goes through the Fusion server and its one credential
--     (REST Data Source FUSION_ROOT on the Fusion Remote Server; XXFND_INTEGRATION_PKG.CALL logs and retries).
--   - Feature FUSION_OBJECTS (module Integrations, View / Create / Manage) with pages 190 Fusion Objects, 191 Onboard
--     Object, 192 Object Detail, 193 Drift Queue, 194 Run Log; the Common Administrator gets the three privileges.
--   - Notification template XXFND_FI_ALERT (run failures, drift waiting for approval).
--   - COMMON's menu gets the feature's entry (XXFND_APPLICATION_PKG.SYNC_MENU adds only what is missing).
-- Idempotent: every routine adds only what is missing.
--------------------------------------------------------------------------------
begin
    xxfnd_util_pkg.set_install_mode(true);

    xxfnd_error_pkg.register_message('XXFND_FI_NO_BICC',
        'The Fusion credential has no access to BICC (HTTP {1}): give its Fusion user the BI Applications administration duty.', -20360);
    xxfnd_error_pkg.register_message('XXFND_FI_NO_METADATA', 'No metadata was returned for {1}.', -20361);
    xxfnd_error_pkg.register_message('XXFND_FI_UNKNOWN', 'Fusion object {1} does not exist.', -20362);
    xxfnd_error_pkg.register_message('XXFND_FI_NO_ATTRIBUTES', 'Fusion object {1}: select at least one attribute.', -20363);
    xxfnd_error_pkg.register_message('XXFND_FI_NO_KEY',
        'Fusion object {1}: a replica needs its primary key attributes selected.', -20364);
    xxfnd_error_pkg.register_message('XXFND_FI_NO_STORAGE',
        'Fusion object {1}: choose the Object Storage server and bucket its BICC extract is written to.', -20365);
    xxfnd_error_pkg.register_message('XXFND_FI_NOT_ALLOWED', 'You need the privilege {1} to change Fusion objects.', -20366);
    xxfnd_error_pkg.register_message('XXFND_FI_MODE', 'Unknown mode {1}: use REPLICA, REALTIME or PUSH.', -20367);
    xxfnd_error_pkg.register_message('XXFND_FI_RETIRED', 'Fusion object {1} is retired.', -20368);
    xxfnd_error_pkg.register_message('XXFND_FI_STATUS', 'Fusion object {1} cannot become {2} from its current status.', -20369);
    xxfnd_error_pkg.register_message('XXFND_FI_DRIFT_DONE', 'Drift {1} was already decided.', -20370);
    xxfnd_error_pkg.register_message('XXFND_FI_NOT_RUNNABLE',
        'Fusion object {1} cannot run in this way (it must be active and in the right mode).', -20371);
    xxfnd_error_pkg.register_message('XXFND_FI_CHILD_REPLICA',
        'Fusion object {1} is a child resource: use it in real-time mode (it is read under its parent row).', -20372);

    xxfnd_integration_pkg.register_purpose('COMMON', 'FUSION_OBJECTS', 'Fusion Objects engine', 'API', 'FUSION_ROOT');

    xxfnd_privilege_pkg.register_feature('COMMON', 'FUSION_OBJECTS', 'Fusion Objects', 'INTEGRATIONS', 620, 'Y', 190,
        'fa-cloud-download', 'Onboard Fusion BICC view objects and REST resources from live metadata: replica, real-time or push.');
    for a in (select column_value action from table(apex_t_varchar2('VIEW', 'CREATE', 'MANAGE'))) loop
        xxfnd_privilege_pkg.register_privilege('COMMON', 'FUSION_OBJECTS', a.action);
        xxfnd_privilege_pkg.add_role_privilege('COMMON', 'COMMON_ADMIN', 'FUSION_OBJECTS.' || a.action);
    end loop;
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'FUSION_OBJECTS', 190, 'Objects', 10);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'FUSION_OBJECTS', 191);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'FUSION_OBJECTS', 192);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'FUSION_OBJECTS', 193, 'Drift Queue', 20);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'FUSION_OBJECTS', 194, 'Run Log', 30);

    xxfnd_notify_pkg.register_template('COMMON', 'XXFND_FI_ALERT', 'Fusion Objects: #OBJECT#',
        'Fusion object #OBJECT#: #EVENT#');

    xxfnd_application_pkg.sync_menu('COMMON');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
