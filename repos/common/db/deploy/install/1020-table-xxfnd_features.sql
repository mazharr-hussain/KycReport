--------------------------------------------------------------------------------
-- C02 Security framework (release R10)
-- Features -> privileges (VIEW / CREATE / MANAGE) -> roles, maintained in the
-- application. Pages map to features, so rebuilding a screen only changes the
-- mapping. Row-level data security: typed rules enforced by one generic VPD
-- policy. Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create table if not exists xxfnd_features (
    feature_code           varchar2(30)   not null,
    feature_name           varchar2(240)  not null,
    feature_group          varchar2(30)   not null,
    display_sequence       number         default 100 not null,
    admin_flag             varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_features_pk primary key (feature_code),
    constraint xxfnd_features_ck1 check (admin_flag in ('Y','N')),
    constraint xxfnd_features_ck2 check (enabled_flag in ('Y','N'))
);
comment on table xxfnd_features is 'Application features (one menu entry each). Privileges are granted per feature and action.';
