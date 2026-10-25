# data-model

```mermaid
graph LR
    xxfnd_data_model_pkg --> xxfnd_application_pkg
    xxfnd_data_model_pkg --> xxfnd_applications
    xxfnd_data_model_pkg --> xxfnd_dm_app_scopes
    xxfnd_data_model_pkg --> xxfnd_dm_table_groups
    xxfnd_data_model_pkg --> xxfnd_error_pkg
    xxfnd_data_model_pkg --> xxfnd_privilege_pkg
    xxfnd_data_model_pkg --> xxfnd_util_pkg
    xxfnd_data_model_pkg --> xxfnd_vpd_pkg
    xxfnd_dm_app_scopes --> xxfnd_applications
    xxfnd_dm_app_scopes --> xxfnd_ddl_pkg
    xxfnd_dm_table_groups --> xxfnd_applications
    xxfnd_dm_table_groups --> xxfnd_data_model_pkg
    xxfnd_dm_table_groups --> xxfnd_ddl_pkg
```
