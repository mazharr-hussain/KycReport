create index xxcus.xxfnd_lookup_values_n1 on
    xxcus.xxfnd_lookup_values (
        parent_lookup_type,
        parent_lookup_code
    );


-- sqlcl_snapshot {"hash":"3cd40184165b36a46558ced6f29c06140e3c2a15","type":"INDEX","name":"XXFND_LOOKUP_VALUES_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_LOOKUP_VALUES_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_LOOKUP_VALUES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>PARENT_LOOKUP_TYPE</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>PARENT_LOOKUP_CODE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}