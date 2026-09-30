create index xxcus.xxfnd_transmissions_n1 on
    xxcus.xxfnd_transmissions (
        entity_name,
        pk1_value
    );


-- sqlcl_snapshot {"hash":"8a20010e13c52d01d1857f59790eeb876c22b0e0","type":"INDEX","name":"XXFND_TRANSMISSIONS_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_TRANSMISSIONS_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_TRANSMISSIONS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>ENTITY_NAME</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>PK1_VALUE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}