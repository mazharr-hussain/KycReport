
-- Release 86: the storage of every registered application (CATEGORY_CODE empty) and of each of its categories (its
-- own and the shared ones), with the value each field takes and whether the setup is complete. XXFND_ATTACH_PKG
-- stores by it; the Storage screens (136, 137) show it.
create or replace view xxfnd_app_storage_v as
with lines as (
    select a.application_code, a.application_name,
           case when a.application_code = 'COMMON' then null else a.application_code end as storage_app,
           cast(null as varchar2(30)) as category_code, cast(null as varchar2(240)) as category_name
      from xxfnd_applications a
    union all
    select a.application_code, a.application_name,
           case when a.application_code = 'COMMON' then null else a.application_code end,
           c.category_code, c.category_name
      from xxfnd_applications a
      join xxfnd_document_categories c on c.application_code = a.application_code or c.application_code is null
), eff as (
    select l.application_code, l.application_name, l.category_code, l.category_name,
           r.storage_config_id, d.storage_config_id as default_config_id,
           r.server_code, r.storage_type,
           r.sharepoint_site_id as site, r.sharepoint_drive_id as library, r.bucket_name as bucket,
           r.ucm_security_group as security_group, r.ucm_doc_account as account, r.ucm_doc_type as document_type,
           r.folder_path_template as folder,
           case when r.storage_type = 'DATABASE' then null else coalesce(r.server_code, d.server_code) end
                                                                             as effective_server_code,
           coalesce(r.sharepoint_site_id, d.sharepoint_site_id)              as effective_site,
           coalesce(r.sharepoint_drive_id, d.sharepoint_drive_id)            as effective_library,
           coalesce(r.bucket_name, d.bucket_name)                            as effective_bucket,
           coalesce(r.ucm_security_group, d.ucm_security_group)              as effective_security_group,
           coalesce(r.ucm_doc_account, d.ucm_doc_account)                    as effective_account,
           coalesce(r.ucm_doc_type, d.ucm_doc_type)                          as effective_document_type,
           coalesce(r.folder_path_template, d.folder_path_template, '/#CATEGORY#/#ENTITY_NAME#/#PK1_VALUE#')
                                                                             as effective_folder
      from lines l
      left join xxfnd_storage_config r
        on r.enabled_flag = 'Y'
       and nvl(r.application_code, '#') = nvl(l.storage_app, '#')
       and nvl(r.category_code, '#') = nvl(l.category_code, '#')
      left join xxfnd_storage_config d
        on d.enabled_flag = 'Y'
       and nvl(d.application_code, '#') = nvl(l.storage_app, '#')
       and d.category_code is null
), chk as (
    select e.*, s.server_type as effective_server_type, s.server_name as effective_server_name,
           case when e.effective_server_code is null then null
                when s.usage <> 'STORAGE' then 'the server is not a storage server'
                when s.status = 'DISABLED' then 'the server is disabled'
                when s.status = 'INCOMPLETE' then 'the server needs ' || s.missing
                when s.server_type = 'SHAREPOINT' and (e.effective_site is null or e.effective_library is null)
                     then 'the site and document library'
                when s.server_type = 'OBJECT_STORAGE' and e.effective_bucket is null then 'the bucket'
                when s.server_type = 'UCM' and e.effective_security_group is null then 'the security group'
           end as incomplete_reason
      from eff e
      left join xxfnd_servers_v s on s.server_code = e.effective_server_code
)
select c.application_code, c.application_name, c.category_code, c.category_name,
       c.storage_config_id, c.default_config_id,
       c.server_code,
       case when c.storage_type = 'DATABASE' then 'DATABASE'
            else (select max(v.server_type) from xxfnd_servers v where v.server_code = c.server_code) end as server_type,
       c.site, c.library, c.bucket, c.security_group, c.account, c.document_type, c.folder,
       c.effective_server_code, c.effective_server_name,
       case when c.effective_server_code is null then 'DATABASE' else c.effective_server_type end as effective_server_type,
       c.effective_site, c.effective_library, c.effective_bucket, c.effective_security_group, c.effective_account,
       c.effective_document_type, c.effective_folder,
       -- what an upload uses now: the effective store when complete, else the database
       case when c.incomplete_reason is null and c.effective_server_code is not null
            then c.effective_server_type else 'DATABASE' end                  as effective_storage_type,
       case when c.incomplete_reason is null then 'OK' else 'INCOMPLETE - using database' end as state,
       c.incomplete_reason
  from chk c;
