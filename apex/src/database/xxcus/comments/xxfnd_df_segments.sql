comment on table xxcus.xxfnd_df_segments is
    'Segments (FND_DESCR_FLEX_COLUMN_USAGES): maps a field to one reserved column. XXFND_DFF_PKG also checks that the column family matches the value set format and that GLOBAL columns are not reused by other contexts.'
    ;

comment on column xxcus.xxfnd_df_segments.default_value is
    'CONSTANT: the literal. SQL: a query returning one value; may reference :CONTEXT_CODE.';


-- sqlcl_snapshot {"hash":"7c32ecf1cfefec529e6d69a0d4a2629a5b9d5787","type":"COMMENT","name":"xxfnd_df_segments","schemaName":"xxcus","sxml":""}