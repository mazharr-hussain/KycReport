-- Release 96 browser test setup (run as XXFUSION before r96_security_ui.py; r96_security_ui_cleanup.sql removes it):
-- departments, KYC Requests and a second test object on the Department dimension, Requester reaching both by values.
begin
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_vpd_pkg.save_organization('COMMON', 'DEPARTMENT', 'FINANCE', 'Finance');
    xxfnd_vpd_pkg.save_organization('COMMON', 'DEPARTMENT', 'PROCUREMENT', 'Procurement');
    xxfnd_vpd_pkg.register_data_object('KYC', 'XXCMP_REQUESTS', 'KYC Requests', 'XXCMP_REQUESTS', 'DEPARTMENT',
                                       'REQUESTING_DEPARTMENT', 'REQUESTER_USER_NAME');
    xxfnd_vpd_pkg.register_data_object('KYC', 'R96_PATHS', 'Approval Paths (test)', 'XXCMP_APPROVAL_PATHS', 'DEPARTMENT',
                                       'REQUESTING_DEPARTMENT');
    xxfnd_vpd_pkg.grant_data_access('KYC', 'REQUESTER', 'XXCMP_REQUESTS', 'VALUES');
    xxfnd_vpd_pkg.grant_data_access('KYC', 'REQUESTER', 'R96_PATHS', 'VALUES');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
end;
/
exit
