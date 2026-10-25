
create or replace view xxfnd_document_versions_v as
select d.document_id,
       nvl(d.base_document_id, d.document_id) base_document_id,
       d.version_number,
       d.file_name,
       d.mime_type,
       d.file_size_bytes,
       d.storage_type,
       d.external_version_id,
       d.document_date,
       d.expiry_date,
       d.created_by,
       d.creation_date
  from xxfnd_documents d
 where d.datatype_code = 'FILE';
