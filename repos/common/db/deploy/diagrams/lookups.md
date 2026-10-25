# lookups

```mermaid
graph LR
    xxfnd_lookup_pkg --> xxfnd_application_pkg
    xxfnd_lookup_pkg --> xxfnd_error_pkg
    xxfnd_lookup_pkg --> xxfnd_lookup_types
    xxfnd_lookup_pkg --> xxfnd_lookup_values
    xxfnd_lookup_pkg --> xxfnd_util_pkg
    xxfnd_lookup_types --> xxfnd_ddl_pkg
    xxfnd_lookup_values --> xxfnd_ddl_pkg
    xxfnd_lookup_values --> xxfnd_lookup_types
    xxfnd_lookup_values_lvl --> xxfnd_lookup_types
    xxfnd_lookup_values_lvl --> xxfnd_lookup_values
    xxfnd_lookup_values_lvl --> xxfnd_util_pkg
    xxfnd_lookup_values_vl --> xxfnd_lookup_values
    xxfnd_lookup_values_vl --> xxfnd_util_pkg
```
