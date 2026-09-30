create index xxcus.xxcmp_parties_n3 on
    xxcus.xxcmp_parties ( upper(replace(id_number, ' ')) );


-- sqlcl_snapshot {"hash":"2ed62be31d7f496558a6e3a737db0ea5ea8c5563","type":"INDEX","name":"XXCMP_PARTIES_N3","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_PARTIES_N3</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_PARTIES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>UPPER(REPLACE(\"ID_NUMBER\",' '))</DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}