comment on table xxcus.xxfnd_attachment_functions is
    'An APEX page that shows attachments (FND_ATTACHMENT_FUNCTIONS). Keyed by application alias, which stays stable across imports; the numeric application ID does not.'
    ;

comment on column xxcus.xxfnd_attachment_functions.allowed_file_types is
    'File extensions accepted on this page unless the category says otherwise; overrides the application default.';

comment on column xxcus.xxfnd_attachment_functions.max_file_size_mb is
    'Largest file accepted on this page (MB) unless the category says otherwise; overrides the application default.';


-- sqlcl_snapshot {"hash":"8ae7d8a09c121cb90f86d044c9653e903b445e43","type":"COMMENT","name":"xxfnd_attachment_functions","schemaName":"xxcus","sxml":""}