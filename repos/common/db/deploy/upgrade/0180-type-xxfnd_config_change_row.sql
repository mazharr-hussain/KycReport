
-- release 48: one pending configuration change (approval unit) for XXFND_APPROVAL_PKG.CONFIG_CHANGES
create or replace type xxfnd_config_change_row force as object (
    detail_pk      varchar2(400),
    change_type    varchar2(240),
    change_title   varchar2(4000),
    change_summary varchar2(4000),
    submitted_by   varchar2(255),
    submitted_date timestamp
);
/
