# change-approvals

```mermaid
graph LR
    xxfnd_approval_pkg --> xxfnd_application_pkg
    xxfnd_approval_pkg --> xxfnd_applications
    xxfnd_approval_pkg --> xxfnd_audit_pkg
    xxfnd_approval_pkg --> xxfnd_config_change_row
    xxfnd_approval_pkg --> xxfnd_config_change_tab
    xxfnd_approval_pkg --> xxfnd_config_changes_v
    xxfnd_approval_pkg --> xxfnd_config_tables
    xxfnd_approval_pkg --> xxfnd_util_pkg
    xxfnd_approval_pkg --> xxfnd_vpd_pkg
    xxfnd_approval_pkg --> xxfnd_workflow_pkg
    xxfnd_config_change_tab --> xxfnd_config_change_row
    xxfnd_config_changes_v --> xxfnd_approval_pkg
    xxfnd_config_tables --> xxfnd_applications
```
