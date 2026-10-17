
-- One approval unit per CONFIG_CHANGE task. DETAIL_PK = '<TABLE>:<KEY>' is the task's detail key.
create or replace view xxfnd_config_changes_v as
select detail_pk, change_type, change_title, change_summary, submitted_by, submitted_date
  from table(xxfnd_approval_pkg.config_changes);
comment on table xxfnd_config_changes_v is 'Maker-checker changes waiting for approval, one row per CONFIG_CHANGE approval task (DETAIL_PK), from every application.';
