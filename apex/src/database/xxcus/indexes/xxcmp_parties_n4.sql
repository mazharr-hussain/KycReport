create index xxcus.xxcmp_parties_n4 on
    xxcus.xxcmp_parties ( upper(replace(registration_number, ' ')) );


-- sqlcl_snapshot {"hash":"ef4446217097bdb53e10f05f0b3dcdce5fa7f5eb","type":"INDEX","name":"XXCMP_PARTIES_N4","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_PARTIES_N4</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_PARTIES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>UPPER(REPLACE(\"REGISTRATION_NUMBER\",' '))</DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}