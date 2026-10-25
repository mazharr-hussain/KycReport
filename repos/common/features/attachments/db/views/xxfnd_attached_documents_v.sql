
create or replace view xxfnd_attached_documents_v as
select ad.attached_document_id,
       ad.entity_name,
       ad.pk1_value, ad.pk2_value, ad.pk3_value, ad.pk4_value, ad.pk5_value,
       ad.category_code,
       c.category_name,
       ad.seq_num,
       ad.primary_category_flag,
       d.document_id,
       d.base_document_id,
       d.version_number,
       d.datatype_code,
       nvl(dt.title, d.file_name)         title,
       dt.description,
       d.file_name,
       d.mime_type,
       d.file_size_bytes,
       d.url,
       d.external_url,
       d.storage_type,
       d.document_date,
       d.expiry_date,
       case when d.expiry_date < trunc(sysdate) then 'Y' else 'N' end expired_flag,
       d.upload_status,
       d.upload_error,
       d.automated_check_status,
       ad.created_by,
       ad.creation_date
  from xxfnd_attached_documents ad
  join xxfnd_documents d on d.document_id = ad.document_id
  join xxfnd_document_categories_vl c on c.category_code = ad.category_code
  left join xxfnd_documents_tl dt
    on dt.document_id = d.document_id
   and dt.language_code = xxfnd_util_pkg.current_lang
 where ad.expiration_date is null;
