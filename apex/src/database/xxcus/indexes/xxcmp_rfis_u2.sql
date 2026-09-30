create unique index xxcus.xxcmp_rfis_u2 on
    xxcus.xxcmp_rfis (
        response_token_hash
    );


-- sqlcl_snapshot {"hash":"13e7d0bd713e211b3e369a1fa1bcc99c9b738408","type":"INDEX","name":"XXCMP_RFIS_U2","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <UNIQUE></UNIQUE>\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_RFIS_U2</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_RFIS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>RESPONSE_TOKEN_HASH</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}