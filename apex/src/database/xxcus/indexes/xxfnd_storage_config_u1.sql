create unique index xxcus.xxfnd_storage_config_u1 on
    xxcus.xxfnd_storage_config ( nvl(entity_name, '#'),
    nvl(category_code, '#') );


-- sqlcl_snapshot {"hash":"a4b067179ab145953e558218f5818ff275502526","type":"INDEX","name":"XXFND_STORAGE_CONFIG_U1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <UNIQUE></UNIQUE>\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_STORAGE_CONFIG_U1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_STORAGE_CONFIG</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>NVL(\"ENTITY_NAME\",'#')</DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>NVL(\"CATEGORY_CODE\",'#')</DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}