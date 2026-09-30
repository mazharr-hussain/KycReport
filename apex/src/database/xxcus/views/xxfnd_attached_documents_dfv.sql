create or replace force editionable view xxcus.xxfnd_attached_documents_dfv (
    attached_document_id,
    context_code
) as
    select
        t.attached_document_id,
        t.attribute_category context_code
    from
        xxfnd_attached_documents t;


-- sqlcl_snapshot {"hash":"4e1360253219bde568c3fd6220e7d189b1540ae8","type":"VIEW","name":"XXFND_ATTACHED_DOCUMENTS_DFV","schemaName":"XXCUS","sxml":""}