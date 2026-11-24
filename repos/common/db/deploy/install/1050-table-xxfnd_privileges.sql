
create table if not exists xxfnd_privileges (
    privilege_code         varchar2(61)   not null,
    feature_code           varchar2(30)   not null,
    action_code            varchar2(20)   not null,
    privilege_name         varchar2(240)  not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_privileges_pk primary key (privilege_code),
    constraint xxfnd_privileges_uk1 unique (feature_code, action_code),
    constraint xxfnd_privileges_fk1 foreign key (feature_code) references xxfnd_features (feature_code),
    constraint xxfnd_privileges_ck1 check (action_code in ('VIEW','CREATE','MANAGE')),
    constraint xxfnd_privileges_ck2 check (privilege_code = feature_code || '.' || action_code)
);
comment on table xxfnd_privileges is 'VIEW = open and read; CREATE = new records; MANAGE = change existing records (edit, delete, actions).';
