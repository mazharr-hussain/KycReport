
-- release 48: each application lists its own pending configuration changes in a view registered in
-- XXFND_CONFIG_TABLES.CHANGES_VIEW; the shared views below read them all (XXFND_APPROVAL_PKG.CONFIG_CHANGES).

-- the shared module's own maker-checker table: integration purposes
create or replace view xxfnd_integration_changes_v as
select 'XXFND_INTEGRATION_PURPOSES:' || p.purpose_code                           detail_pk,
       'Integration purpose'                                                    change_type,
       p.purpose_name                                                           change_title,
       p.capture_method || ' / ' || nvl(p.endpoint_code, 'no endpoint')         change_summary,
       p.last_updated_by                                                        submitted_by,
       p.last_update_date                                                       submitted_date
  from xxfnd_integration_purposes p
 where p.approval_status = 'PENDING_APPROVAL';
