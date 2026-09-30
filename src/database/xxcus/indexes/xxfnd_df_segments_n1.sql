create index xxcus.xxfnd_df_segments_n1 on
    xxcus.xxfnd_df_segments (
        value_set_code
    );


-- sqlcl_snapshot {"hash":"e036dd44e652dc5ad30d55546c13023ed92e7892","type":"INDEX","name":"XXFND_DF_SEGMENTS_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_DF_SEGMENTS_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_DF_SEGMENTS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>VALUE_SET_CODE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}