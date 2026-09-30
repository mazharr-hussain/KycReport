comment on table xxcus.xxfnd_lookup_types is
    'Lookup type header (FND_LOOKUP_TYPES). APPLICATION_CODE null = shared by every application.';

comment on column xxcus.xxfnd_lookup_types.customization_level is
    'S = system (values locked), E = extensible (values may be added), U = user (fully editable).';


-- sqlcl_snapshot {"hash":"1077b907095346485b8dff66a914a8ca1e2ee765","type":"COMMENT","name":"xxfnd_lookup_types","schemaName":"xxcus","sxml":""}