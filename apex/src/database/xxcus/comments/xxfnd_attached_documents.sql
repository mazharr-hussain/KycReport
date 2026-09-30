comment on table xxcus.xxfnd_attached_documents is
    'Links a document to any record of a registered entity (FND_ATTACHED_DOCUMENTS). Carries its own descriptive flexfield.';

comment on column xxcus.xxfnd_attached_documents.expiration_date is
    'Soft delete. A removed attachment keeps its row and audit history.';


-- sqlcl_snapshot {"hash":"6f884fb57307c33acc4fd14b824fb10335b9d04d","type":"COMMENT","name":"xxfnd_attached_documents","schemaName":"xxcus","sxml":""}