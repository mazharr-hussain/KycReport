create index xxcus.xxfnd_transmissions_n2 on
    xxcus.xxfnd_transmissions (
        status_code,
        sent_date
    );


-- sqlcl_snapshot {"hash":"8dc1a2a375228475efe453a142c16c8daeb1786b","type":"INDEX","name":"XXFND_TRANSMISSIONS_N2","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_TRANSMISSIONS_N2</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_TRANSMISSIONS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>STATUS_CODE</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>SENT_DATE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}