create unique index xxcus.xxfnd_retention_policies_u1 on
    xxcus.xxfnd_retention_policies (
        table_name,
    nvl(jurisdiction, '#') );


-- sqlcl_snapshot {"hash":"03f41eb81f114c6b360e25918ee18b28e6333b3c","type":"INDEX","name":"XXFND_RETENTION_POLICIES_U1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <UNIQUE></UNIQUE>\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_RETENTION_POLICIES_U1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_RETENTION_POLICIES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>TABLE_NAME</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>NVL(\"JURISDICTION\",'#')</DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}