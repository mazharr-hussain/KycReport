comment on table xxcus.xxfnd_df_flexfields is
    'One DFF per table (FND_DESCRIPTIVE_FLEXS). Registering a table here plus enabling contexts and segments is all it takes for every screen carrying the DFF region to render the fields.'
    ;

comment on column xxcus.xxfnd_df_flexfields.context_reference_column is
    'Derive the context from this column on the same row, e.g. JURISDICTION (FND_DEFAULT_CONTEXT_FIELDS).';

comment on column xxcus.xxfnd_df_flexfields.context_user_selectable_flag is
    'Y = when no reference column, the user picks the context from a list.';


-- sqlcl_snapshot {"hash":"93a83feed90d5c4b6ccf11b38a7308c6a791283d","type":"COMMENT","name":"xxfnd_df_flexfields","schemaName":"xxcus","sxml":""}