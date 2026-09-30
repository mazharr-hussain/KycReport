comment on column xxcus.xxfnd_document_categories.allowed_file_types is
    'File extensions accepted for this category, comma-separated (e.g. pdf,jpg); * = any; overrides the page and the application default.'
    ;

comment on column xxcus.xxfnd_document_categories.has_expiry_flag is
    'Y = the document itself expires (passport, licence); an expiry date is required on upload.';

comment on column xxcus.xxfnd_document_categories.max_age_days is
    'How recent the document must be when submitted (e.g. utility bill within 90 days). Separate from expiry.';

comment on column xxcus.xxfnd_document_categories.max_file_size_mb is
    'Largest file accepted for this category (MB); overrides the page and the application default.';


-- sqlcl_snapshot {"hash":"88e550e4053a25b6de0a1c3191decf51ce1b380c","type":"COMMENT","name":"xxfnd_document_categories","schemaName":"xxcus","sxml":""}