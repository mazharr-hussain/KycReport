comment on table xxcus.xxfnd_documents is
    'Document header (FND_DOCUMENTS). Files are held in UCM or SharePoint; the database keeps only the reference. Text and web-page documents need no external store.'
    ;

comment on column xxcus.xxfnd_documents.automated_check_status is
    'Reserved for an automated authenticity check (integration purpose DOC_AUTHENTICITY).';

comment on column xxcus.xxfnd_documents.base_document_id is
    'First version of this document. Null on the first version; later versions point back to it.';

comment on column xxcus.xxfnd_documents.document_date is
    'Issue date printed on the document. Checked against the category''s MAX_AGE_DAYS.';

comment on column xxcus.xxfnd_documents.external_document_id is
    'UCM dDocName, or SharePoint drive item ID.';

comment on column xxcus.xxfnd_documents.external_version_id is
    'UCM dID, or SharePoint version label.';

comment on column xxcus.xxfnd_documents.upload_status is
    'PENDING until the external store confirms the file; FAILED keeps the error in UPLOAD_ERROR so nothing is silently lost.';


-- sqlcl_snapshot {"hash":"9adcab5974c730e14e4d1eb31e2ae59937b32223","type":"COMMENT","name":"xxfnd_documents","schemaName":"xxcus","sxml":""}