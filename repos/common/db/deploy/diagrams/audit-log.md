# audit-log

```mermaid
graph LR
    xxfnd_audit_log --> xxfnd_audit_pkg
    xxfnd_audit_log --> xxfnd_ddl_pkg
    xxfnd_audit_pkg --> xxfnd_audit_log
    xxfnd_audit_pkg --> xxfnd_schema_pkg
    xxfnd_audit_pkg --> xxfnd_util_pkg
```
