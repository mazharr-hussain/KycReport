comment on table xxcus.xxfnd_value_sets is
    'Segment validation (FND_FLEX_VALUE_SETS). INDEPENDENT/DEPENDENT sets draw values from the Lookup engine; DEPENDENT uses the parent columns on XXFND_LOOKUP_VALUES.'
    ;

comment on column xxcus.xxfnd_value_sets.table_query is
    'TABLE validation only. Must return RETURN_VALUE and DISPLAY_VALUE; may reference :CONTEXT_CODE.';


-- sqlcl_snapshot {"hash":"6a898f4e3ec1dcbbeaab7c59cd50d52bce1cbda6","type":"COMMENT","name":"xxfnd_value_sets","schemaName":"xxcus","sxml":""}