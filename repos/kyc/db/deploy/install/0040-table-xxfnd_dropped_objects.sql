
-- release 78: what DROP_OBJECT dropped - its DDL and the objects that depended on it (never purged)
create table if not exists xxfnd_dropped_objects (
    object_name            varchar2(128)  not null,
    object_type            varchar2(30)   not null,
    dependents             varchar2(4000),
    object_ddl             clob,
    dropped_date           timestamp      default systimestamp not null,
    dropped_by             varchar2(255)  not null
);
