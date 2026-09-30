create or replace force editionable view xxcus.xxfnd_document_versions_v (
    document_id,
    base_document_id,
    version_number,
    file_name,
    mime_type,
    file_size_bytes,
    storage_type,
    external_version_id,
    document_date,
    expiry_date,
    created_by,
    creation_date
) as
    select
        d.document_id,
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
    from
        xxfnd_documents d
    where
        d.datatype_code = 'FILE';


-- sqlcl_snapshot {"hash":"de70344e3c836850e8d03f38e8f192b81b80e09a","type":"VIEW","name":"XXFND_DOCUMENT_VERSIONS_V","schemaName":"XXCUS","sxml":""}